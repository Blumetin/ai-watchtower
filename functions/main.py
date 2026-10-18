import json
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from hashlib import sha256

from firebase_admin import firestore, initialize_app
from firebase_functions import firestore_fn, https_fn, options, scheduler_fn
from google.api_core.exceptions import NotFound

from watchtower.fetch_ncdr import fetch_alerts
from watchtower.normalize import pipeline

initialize_app()
BATCH_LIMIT = 500
REGION = "asia-east1"
GEMINI_SECRET = "GEMINI_API_KEY"
CWA_SECRET = "CWA_API_KEY"
ASK_PER_HOUR = 30
REPORT_PER_HOUR = 10
MAX_QUESTION = 300


def _commit_in_batches(db, ops):
    for i in range(0, len(ops), BATCH_LIMIT):
        batch = db.batch()
        for kind, ref, data in ops[i:i + BATCH_LIMIT]:
            if kind == "set":
                batch.set(ref, data, merge=True)
            else:
                batch.delete(ref)
        batch.commit()


HISTORY_DAYS = 90
NEW_WINDOW = timedelta(minutes=30)


def _to_history(doc: dict, status: str, now: datetime) -> dict:
    doc = dict(doc)
    doc.update(status=status, ended_at=now, purge_at=now + timedelta(days=HISTORY_DAYS))
    return doc


def sync_alerts(db, raw_alerts: list[dict]) -> dict:
    alerts = pipeline(raw_alerts)
    now = datetime.now(timezone.utc)
    in_db = {snap.id: snap.to_dict() for snap in db.collection("alerts").stream()}
    counts = defaultdict(int)
    ops, handled = [], set()
    for a in alerts:
        status = a.status
        counts[status] += 1
        handled.add(a.uid)
        if status == "active":
            if a.uid not in in_db:
                doc = a.to_dict()
                doc.update(status="active", synced_at=now)
                ops.append(("set", db.collection("alerts").document(a.uid), doc))
                counts["new_active"] += 1
        elif a.uid in in_db:
            ops.append(("set", db.collection("history").document(a.uid), _to_history(in_db[a.uid], status, now)))
            ops.append(("delete", db.collection("alerts").document(a.uid), None))
            counts["moved"] += 1
        elif now - a.updated <= NEW_WINDOW:
            doc = a.to_dict()
            doc["synced_at"] = now
            ops.append(("set", db.collection("history").document(a.uid), _to_history(doc, status, now)))
            counts["new_history"] += 1

    for uid, d in in_db.items():
        exp = d.get("expires")
        if uid not in handled and exp and datetime.fromisoformat(exp) < now:
            ops.append(("set", db.collection("history").document(uid), _to_history(d, "expired", now)))
            ops.append(("delete", db.collection("alerts").document(uid), None))
            counts["expired_in_db"] += 1

    _commit_in_batches(db, ops)
    counts["ops"] = len(ops)
    return dict(counts)


STATUS_EVERY = timedelta(minutes=10)


def _write_status(db, name: str, ok: bool, fields: dict | None = None, error: Exception | None = None) -> None:
    now = datetime.now(timezone.utc)
    doc = {"last_run_at": now, "ok": ok, "last_error": None if ok else type(error).__name__}
    if ok:
        doc["last_ok_at"] = now
        doc.update(fields or {})
    try:
        db.collection("meta").document(name).set(doc, merge=True)
    except Exception as e:
        print("meta 寫入失敗", name, type(e).__name__)


@scheduler_fn.on_schedule(schedule="3-59/10 * * * *", region="asia-east1",
                          timezone=scheduler_fn.Timezone("Asia/Taipei"), timeout_sec=120)
def poll_alerts(event: scheduler_fn.ScheduledEvent) -> None:
    db = firestore.client()
    try:
        counts = sync_alerts(db, fetch_alerts())
    except Exception as e:
        _write_status(db, "sync_status", ok=False, error=e)
        raise
    _write_status(db, "sync_status", ok=True, fields={"active_count": counts.get("active", 0)})
    print("poll_alerts", counts)
    try:
        from watchtower.push import sweep
        sweep(db)
    except Exception as e:
        print(json.dumps({"severity": "WARNING", "message": "push_sweep_failed", "error": type(e).__name__}))
    if datetime.now(timezone.utc).minute < 10:
        try:
            from watchtower.usage import record_previous_hour
            record_previous_hour(db)
        except Exception as e:
            print(json.dumps({"severity": "WARNING", "message": "usage_hourly_failed", "error": type(e).__name__}))


@scheduler_fn.on_schedule(schedule="*/2 * * * *", region=REGION, timezone=scheduler_fn.Timezone("Asia/Taipei"),
                          timeout_sec=120, secrets=[CWA_SECRET, GEMINI_SECRET])
def poll_quakes(event: scheduler_fn.ScheduledEvent) -> None:
    from watchtower.quakes import collect, sync_quakes
    db = firestore.client()
    try:
        quakes, counts = collect()
        counts.update(sync_quakes(db, quakes))
    except Exception as e:
        _write_status(db, "quake_status", ok=False, error=e)
        _quake_status["at"] = None
        raise
    _report_quake_status(db, counts)
    print("poll_quakes", counts)


_quake_status = {"at": None}


def _report_quake_status(db, counts: dict) -> bool:
    now = datetime.now(timezone.utc)
    if counts["written"] or _quake_status["at"] is None or now - _quake_status["at"] >= STATUS_EVERY:
        _write_status(db, "quake_status", ok=True,
                      fields={"significant_count": counts["significant"], "local_count": counts["local"]})
        _quake_status["at"] = now
        return True
    return False


ENRICH_AI_BUDGET = 90


@firestore_fn.on_document_created(document="alerts/{uid}", region=REGION, secrets=[GEMINI_SECRET],
                                  timeout_sec=120, memory=options.MemoryOption.MB_512, max_instances=10)
def enrich_alert(event: firestore_fn.Event[firestore_fn.DocumentSnapshot | None]) -> None:
    from watchtower.enrich import enrich
    snap = event.data
    if snap is None:
        return
    fields = enrich(snap.to_dict(), ai_budget=ENRICH_AI_BUDGET)
    try:
        snap.reference.update(fields)
    except NotFound:
        print("enrich_alert: 文件已不在 alerts", event.params["uid"])
        return
    print("enrich_alert", event.params["uid"], fields.get("severity"), fields.get("severity_source"),
          fields.get("translation_check"), fields.get("enrich_errors"))
    try:
        from watchtower.push import maybe_push
        maybe_push(firestore.client(), {**snap.to_dict(), **fields, "uid": event.params["uid"]})
    except Exception as e:
        print(json.dumps({"severity": "WARNING", "message": "push_failed", "uid": event.params["uid"],
                          "error": type(e).__name__}))


from watchtower.ratelimit import ip_pepper as _ip_pepper


def _app_check_status(req: https_fn.CallableRequest) -> str:
    if req.app is not None:
        parts = str(req.app.app_id).split(":")
        return f"valid:{parts[2]}:{parts[3][:6]}" if len(parts) == 4 else "valid:?"
    return "invalid" if req.raw_request.headers.get("X-Firebase-AppCheck") else "missing"


def _over_limit(db, raw_request, prefix: str = "", limit: int = ASK_PER_HOUR) -> bool:
    xff = [p.strip() for p in raw_request.headers.get("X-Forwarded-For", "").split(",") if p.strip()]
    ip = xff[-1] if xff else (raw_request.remote_addr or "")
    hour = datetime.now(timezone.utc).strftime("%Y%m%d%H")
    ref = db.collection("rate_limits").document(f"{prefix}{sha256((_ip_pepper(db) + ip).encode()).hexdigest()[:16]}_{hour}")
    ref.set({"n": firestore.Increment(1),
             "expire_at": datetime.now(timezone.utc) + timedelta(hours=2)}, merge=True)
    return ref.get().to_dict().get("n", 0) > limit


@https_fn.on_call(region=REGION, secrets=[GEMINI_SECRET], timeout_sec=60, max_instances=5, min_instances=1, concurrency=20,
                  memory=options.MemoryOption.GB_1, enforce_app_check=True)
def ask(req: https_fn.CallableRequest) -> dict:
    from watchtower import qa
    data = req.data or {}
    question = str(data.get("question", "")).strip()
    lang = str(data.get("lang", "zh"))
    if not question:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "question is required")
    crisis_check_of = str(data.get("crisis_check_of") or "").strip() or None
    if len(question) > MAX_QUESTION or (crisis_check_of and len(crisis_check_of) > MAX_QUESTION):
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "question is too long")
    db = firestore.client()
    if _over_limit(db, req.raw_request):
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, "too many questions")
    qa.set_db(db)
    try:
        result = qa.ask(question, lang, crisis_check_of=crisis_check_of, checked_before=data.get("checked_before") is True)
    except Exception as e:
        print(json.dumps({"severity": "ERROR", "message": "ask_failed", "error": type(e).__name__}))
        result = qa.fallback(question, lang)
    app_check = _app_check_status(req)
    print("ask", result.get("route"), result.get("crisis_source"),
          [t.split("(")[0] for t in result.get("tools") or []], result.get("scores"), result.get("error"), app_check)
    return {k: result[k] for k in ("answer", "sources", "route", "crisis", "crisis_check") if k in result}


from watchtower.report import REPORT_KEEP_DAYS, REPORT_REASONS, over_daily_cap, parse_report


@https_fn.on_call(region=REGION, timeout_sec=30, max_instances=2, memory=options.MemoryOption.MB_256,
                  enforce_app_check=True)
def report_answer(req: https_fn.CallableRequest) -> dict:
    db = firestore.client()
    if _over_limit(db, req.raw_request, prefix="report_", limit=REPORT_PER_HOUR):
        print(json.dumps({"message": "report_answer", "result": "rate_limited"}))
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, "too many reports")
    report, lengths, ok = parse_report(req.data)
    if not ok:
        print(json.dumps({"message": "report_answer", "result": "invalid", "reason": report["reason"] in REPORT_REASONS,
                          "lengths": lengths}))
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "invalid report")
    capped, n = over_daily_cap(db)
    if capped:
        print(json.dumps({"severity": "WARNING", "message": "report_answer", "result": "daily_cap", "count": n}))
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, "too many reports today")
    now = datetime.now(timezone.utc)
    try:
        db.collection("answer_reports").add(report | {"created_at": now, "expires_at": now + timedelta(days=REPORT_KEEP_DAYS)})
    except Exception as e:
        print(json.dumps({"severity": "ERROR", "message": "report_answer", "result": "write_failed", "error": type(e).__name__}))
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INTERNAL, "report failed")
    app_check = _app_check_status(req)
    print(json.dumps({"message": "report_answer", "result": "ok", "reason": report["reason"], "lang": report["lang"],
                      "route": report["route"], "lengths": lengths, "daily_count": n, "app_check": app_check}))
    return {"ok": True}
