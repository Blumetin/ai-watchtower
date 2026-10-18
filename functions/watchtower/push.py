import hashlib
import json
import os
from datetime import datetime, timedelta, timezone

PUSH = {
    "mode": os.environ.get("PUSH_MODE", "off"),
    "levels": ("extreme", "critical"),
    "critical_sources": ("官方等級",),
    "skip_sources": ("AI 判定",),
    "update_policy": "new_counties",
    "repush_on_escalation": False,
    "langs": ("zh", "en", "ja"),
    "topics_per_message": 5,
    "default_ttl_hours": 6,
    "collection": "push_sent",
    "android_channel": "major_alerts",
    "cooldown_minutes": 30,
    "cooldown_collection": "push_cooldown",
    "since": os.environ.get("PUSH_SINCE", ""),
    "sweep_max": 10,
    "sweep_min_age_seconds": 120,
    "sweep_max_retries": 6,
}
LEVEL_RANK = {"critical": 1, "extreme": 2}
LABEL = {"zh": {"extreme": "極重大示警", "critical": "重大示警"},
         "en": {"extreme": "Extreme alert", "critical": "Critical alert"},
         "ja": {"extreme": "極めて重大な警報", "critical": "重大な警報"}}
BODY_MAX = 200


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _parse_time(v) -> datetime | None:
    if isinstance(v, datetime):
        return v if v.tzinfo else v.replace(tzinfo=timezone.utc)
    if isinstance(v, str) and v:
        try:
            t = datetime.fromisoformat(v)
            return t if t.tzinfo else t.replace(tzinfo=timezone(timedelta(hours=8)))
        except ValueError:
            return None
    return None


def collapse_key(uid: str) -> str:
    return uid if len(uid.encode()) <= 64 else hashlib.sha256(uid.encode()).hexdigest()[:32]


def county_levels_to_push(doc: dict) -> tuple[dict[str, str], str]:
    source = doc.get("severity_source")
    severity = doc.get("severity")
    if PUSH["mode"] == "off":
        return {}, "mode_off"
    if source in PUSH["skip_sources"] or source is None:
        return {}, "source_not_official"
    if doc.get("cap_status") not in (None, "Actual"):
        return {}, "not_actual"
    if doc.get("cap_msg_type") == "Cancel":
        return {}, "cancel"
    if doc.get("status") not in (None, "active"):
        return {}, "not_active"
    expires = _parse_time(doc.get("expires"))
    if expires and expires <= _now():
        return {}, "expired"
    levels = {}
    county_levels = doc.get("county_levels") or {}
    for c in doc.get("counties") or []:
        lvl = "extreme" if source == "官方措辭" else county_levels.get(c, severity)
        if lvl not in PUSH["levels"]:
            continue
        if lvl == "critical" and source not in PUSH["critical_sources"]:
            continue
        levels[c] = lvl
    return (levels, "") if levels else ({}, "below_threshold")


def select(want: dict[str, str], pushed: dict[str, str]) -> dict[str, str]:
    if PUSH["update_policy"] == "chain_once" and pushed:
        return {}
    return {c: lvl for c, lvl in want.items()
            if c not in pushed or (PUSH["repush_on_escalation"] and LEVEL_RANK[lvl] > LEVEL_RANK.get(pushed[c], 0))}


def _chain_ids(doc: dict) -> tuple[str, list[str]]:
    ident = doc.get("cap_identifier")
    if not ident:
        return "uid:" + doc["uid"], []
    return "cap:" + ident, ["cap:" + r for r in doc.get("cap_references") or []]


def _coll() -> str:
    return PUSH["collection"] if PUSH["mode"] == "live" else PUSH["collection"] + "_dryrun"


def _cool_coll() -> str:
    return PUSH["cooldown_collection"] if PUSH["mode"] == "live" else PUSH["cooldown_collection"] + "_dryrun"


def _cool_id(county: str, level: str, category: str) -> str:
    return hashlib.sha256(f"{county}|{level}|{category}".encode()).hexdigest()[:40]


def apply_cooldown(send: dict[str, str], last: dict[str, datetime | None], now: datetime) -> tuple[dict, list]:
    keep, blocked = {}, []
    for c, lvl in send.items():
        t = last.get(c)
        if lvl != "extreme" and t is not None and now - t < timedelta(minutes=PUSH["cooldown_minutes"]):
            blocked.append(c)
        else:
            keep[c] = lvl
    return keep, blocked


def _doc_id(key: str) -> str:
    return hashlib.sha256(key.encode()).hexdigest()[:40]


def plan(db, doc: dict) -> tuple[dict[str, str], str, list[str]]:
    from google.cloud import firestore as gfs

    want, reason = county_levels_to_push(doc)
    if not want:
        return {}, reason, []
    key, refs = _chain_ids(doc)
    own_ref = db.collection(_coll()).document(_doc_id(key))
    ref_refs = [db.collection(_coll()).document(_doc_id(r)) for r in refs[-20:]]

    @gfs.transactional
    def txn(t):
        own = own_ref.get(transaction=t)
        if own.exists:
            return {}, "duplicate", []
        pushed: dict[str, str] = {}
        for snap in (r.get(transaction=t) for r in ref_refs):
            if snap.exists:
                for c, lvl in (snap.to_dict().get("counties") or {}).items():
                    if LEVEL_RANK.get(lvl, 0) > LEVEL_RANK.get(pushed.get(c), 0):
                        pushed[c] = lvl
        send = select(want, pushed)
        if not send:
            reason_ = "already_pushed_in_chain"
        else:
            reason_ = ""
        now = _now()
        category = doc.get("raw_category") or "其他"
        cool_refs = {c: db.collection(_cool_coll()).document(_cool_id(c, lvl, category))
                     for c, lvl in send.items() if lvl != "extreme"}
        last = {}
        for c, ref in cool_refs.items():
            snap = ref.get(transaction=t)
            last[c] = snap.to_dict().get("last_at") if snap.exists else None
        send, blocked = apply_cooldown(send, last, now)
        if blocked and not send:
            reason_ = "cooldown"
        covered = {**pushed, **send}
        expires = _parse_time(doc.get("expires")) or now
        t.set(own_ref, {"uid": doc["uid"], "counties": covered, "sent": sorted(send), "cooldown_blocked": sorted(blocked),
                        "mode": PUSH["mode"], "created_at": gfs.SERVER_TIMESTAMP, "expires_at": expires + timedelta(days=30)})
        for c in send:
            if c in cool_refs:
                t.set(cool_refs[c], {"last_at": now, "by": key, "expires_at": now + timedelta(days=1)})
        return send, reason_, blocked

    return txn(db.transaction())


def topics(send: dict[str, str], lang: str, prefix: str = "alert") -> list[str]:
    return [f"{prefix}_{c}_{lvl}_{lang}" for c, lvl in sorted(send.items())]


def _condition(ts: list[str]) -> str:
    return " || ".join(f"'{t}' in topics" for t in ts)


def build_messages(doc: dict, send: dict[str, str], prefix: str = "alert") -> list:
    from firebase_admin import messaging

    level = max(send.values(), key=LEVEL_RANK.get)
    tag = collapse_key(doc["uid"])
    expires = _parse_time(doc.get("expires"))
    ttl = (expires - _now()) if expires else timedelta(hours=PUSH["default_ttl_hours"])
    ttl = max(ttl, timedelta(minutes=5))
    exp_epoch = int((_now() + ttl).timestamp())
    msgs = []
    for lang in PUSH["langs"]:
        title = LABEL[lang][level]
        body = (doc.get("ai_summary") if lang == "zh" else doc.get(f"ai_summary_{lang}")) or \
               (doc.get("title", "") if lang == "zh" else "")
        body = (body or title)[:BODY_MAX]
        data = {"uid": doc["uid"], "title": title, "level": level}
        ts = topics(send, lang, prefix)
        n = PUSH["topics_per_message"]
        for i in range(0, len(ts), n):
            msgs.append(messaging.Message(
                condition=_condition(ts[i:i + n]),
                notification=messaging.Notification(title=title, body=body),
                data=data,
                android=messaging.AndroidConfig(priority="high", ttl=ttl,
                                                notification=messaging.AndroidNotification(
                                                    tag=tag, channel_id=PUSH["android_channel"])),
                apns=messaging.APNSConfig(headers={"apns-collapse-id": tag, "apns-priority": "10",
                                                   "apns-expiration": str(exp_epoch)}),
                webpush=messaging.WebpushConfig(headers={"TTL": str(int(ttl.total_seconds()))},
                                                notification=messaging.WebpushNotification(tag=tag))))
    return msgs


def release(db, doc: dict, send: dict[str, str] | None = None) -> None:
    key, _ = _chain_ids(doc)
    db.collection(_coll()).document(_doc_id(key)).delete()
    category = doc.get("raw_category") or "其他"
    for c, lvl in (send or {}).items():
        if lvl == "extreme":
            continue
        ref = db.collection(_cool_coll()).document(_cool_id(c, lvl, category))
        snap = ref.get()
        if snap.exists and snap.to_dict().get("by") == key:
            ref.delete()


def send_with_retry(msgs: list, dry_run: bool) -> tuple[int, int, list[str]]:
    import time

    from firebase_admin import messaging

    resp = messaging.send_each(msgs, dry_run=dry_run)
    failed = [m for m, r in zip(msgs, resp.responses) if not r.success]
    errors = sorted({type(r.exception).__name__ for r in resp.responses if not r.success})
    ok = resp.success_count
    if failed:
        time.sleep(2)
        retry = messaging.send_each(failed, dry_run=dry_run)
        ok += retry.success_count
        failed = [m for m, r in zip(failed, retry.responses) if not r.success]
    return ok, len(failed), errors


def _log(**kw) -> None:
    print(json.dumps({"severity": "INFO", "message": "push", **kw}, ensure_ascii=False))


def maybe_push(db, doc: dict) -> dict:
    try:
        res = plan(db, doc)
        send, reason = res[0], res[1]
        blocked = res[2] if len(res) > 2 else []
        if not send:
            _log(uid=doc.get("uid"), result="skip", reason=reason, mode=PUSH["mode"], cooldown=len(blocked))
            return {"result": "skip", "reason": reason}
        msgs = build_messages(doc, send)
        try:
            ok, failed, errors = send_with_retry(msgs, dry_run=PUSH["mode"] != "live")
        except Exception as e:
            ok, failed, errors = 0, len(msgs), [type(e).__name__]
        if failed:
            release(db, doc, send)
        _log(uid=doc.get("uid"), result="sent" if not failed else "failed_released", mode=PUSH["mode"],
             counties=len(send), cooldown=len(blocked), messages=len(msgs), ok=ok, failed=failed, errors=errors)
        return {"result": "sent" if not failed else "failed_released", "counties": len(send),
                "messages": len(msgs), "failed": failed}
    except Exception as e:
        print(json.dumps({"severity": "WARNING", "message": "push_failed", "uid": doc.get("uid"),
                          "error": type(e).__name__}))
        return {"result": "error", "error": type(e).__name__}


def sweep(db, now: datetime | None = None) -> dict:
    from collections import Counter

    from google.cloud import firestore as gfs

    now = now or _now()
    since = _parse_time(PUSH["since"])
    stats = Counter()
    if PUSH["mode"] == "off" or not since:
        return {"skipped": "mode_off" if PUSH["mode"] == "off" else "no_since"}
    for snap in db.collection("alerts").stream():
        d = {**snap.to_dict(), "uid": snap.id}
        enriched, synced = _parse_time(d.get("enriched_at")), _parse_time(d.get("synced_at"))
        if not synced or synced < since:
            continue
        if not enriched or (now - enriched).total_seconds() < PUSH["sweep_min_age_seconds"]:
            stats["not_ready"] += 1
            continue
        expires = _parse_time(d.get("expires"))
        if expires and expires <= now:
            continue
        want, _ = county_levels_to_push(d)
        if not want:
            continue
        key, _ = _chain_ids(d)
        if db.collection(_coll()).document(_doc_id(key)).get().exists:
            continue
        if (d.get("push_retry_count") or 0) >= PUSH["sweep_max_retries"]:
            stats["gave_up"] += 1
            continue
        if stats["retried"] >= PUSH["sweep_max"]:
            stats["deferred"] += 1
            continue
        res = maybe_push(db, d)
        snap.reference.update({"push_retry_count": gfs.Increment(1), "push_retry_last": now,
                               "push_retry_result": res.get("result")})
        stats["retried"] += 1
        stats[str(res.get("result"))] += 1
    if stats:
        print(json.dumps({"severity": "WARNING" if stats["gave_up"] else "INFO", "message": "push_sweep",
                          "mode": PUSH["mode"], **stats}))
    return dict(stats)

