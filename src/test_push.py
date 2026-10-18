import io
import json
import sys
from contextlib import redirect_stdout
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "functions"))
import firebase_admin
from firebase_admin import firestore

from watchtower import push

LOG = Path(__file__).parent / "logs" / f"push_{datetime.now():%Y-%m-%d}.txt"
TW = timezone(timedelta(hours=8))
SOON = (datetime.now(TW) + timedelta(hours=3)).isoformat()
PAST = (datetime.now(TW) - timedelta(hours=1)).isoformat()
out, bad = [], 0


def check(name, got, want):
    global bad
    ok = got == want
    bad += not ok
    out.append(f"{'OK' if ok else 'NG'}｜{name}｜得到 {got}" + ("" if ok else f"，預期 {want}"))


def alert(**kw):
    base = {"uid": "TEST_uid_1", "severity": "critical", "severity_source": "官方等級", "status": "active",
            "expires": SOON, "counties": ["tpe"], "county_levels": {}, "cap_status": "Actual", "cap_msg_type": "Alert",
            "cap_identifier": None, "cap_references": [], "title": "大雨特報", "ai_summary": "臺北市豪雨，請注意",
            "ai_summary_en": "Heavy rain in Taipei", "ai_summary_ja": "台北市で大雨"}
    return {**base, **kw}


def main() -> int:
    global out
    push.PUSH["mode"] = "dry_run"
    want = lambda a: push.county_levels_to_push(a)

    out.append("== 一、推播條件 ==")
    check("critical＋官方等級 → 推", want(alert()), ({"tpe": "critical"}, ""))
    check("critical＋AI 判定 → 不推", want(alert(severity_source="AI 判定")), ({}, "source_not_official"))
    check("extreme＋官方等級 → 推", want(alert(severity="extreme")), ({"tpe": "extreme"}, ""))
    check("官方措辭（紅色）→ 全部縣市 extreme", want(alert(severity="extreme", severity_source="官方措辭",
                                                     counties=["tpe", "ila"], county_levels={"ila": "warning"})),
          ({"tpe": "extreme", "ila": "extreme"}, ""))
    check("warning → 不推", want(alert(severity="warning")), ({}, "below_threshold"))
    check("各縣市等級不同：只推達標的縣市", want(alert(counties=["tpe", "ila", "kee"],
                                                county_levels={"tpe": "critical", "ila": "warning", "kee": "extreme"})),
          ({"tpe": "critical", "kee": "extreme"}, ""))
    check("演習（Exercise）→ 不推", want(alert(cap_status="Exercise")), ({}, "not_actual"))
    check("測試（Test）→ 不推", want(alert(cap_status="Test")), ({}, "not_actual"))
    check("解除（Cancel）→ 不推", want(alert(cap_msg_type="Cancel")), ({}, "cancel"))
    check("更新（Update）→ 照規則推（去重另看更新鏈）", want(alert(cap_msg_type="Update")), ({"tpe": "critical"}, ""))
    check("已過期 → 不推", want(alert(expires=PAST)), ({}, "expired"))
    check("狀態不是 active → 不推", want(alert(status="expired")), ({}, "not_active"))
    check("電文抓不到（cap_status 為 None）→ 照等級規則", want(alert(cap_status=None)), ({"tpe": "critical"}, ""))
    push.PUSH["mode"] = "off"
    check("mode off → 不推", want(alert()), ({}, "mode_off"))
    push.PUSH["mode"] = "dry_run"

    out += ["", "== 二、更新鏈去重 select() =="]
    sel = push.select
    check("B：新增縣市才推", sel({"tpe": "critical", "ila": "critical"}, {"tpe": "critical"}), {"ila": "critical"})
    check("B：全部推過 → 不推", sel({"tpe": "critical"}, {"tpe": "critical"}), {})
    check("升級不再推（預設關）", sel({"tpe": "extreme"}, {"tpe": "critical"}), {})
    push.PUSH["repush_on_escalation"] = True
    check("升級再推（設定開）", sel({"tpe": "extreme"}, {"tpe": "critical"}), {"tpe": "extreme"})
    check("升級再推：等級沒升不推", sel({"tpe": "critical"}, {"tpe": "extreme"}), {})
    push.PUSH["repush_on_escalation"] = False
    push.PUSH["update_policy"] = "chain_once"
    check("A（chain_once）：鏈推過就不推新增縣市", sel({"ila": "critical"}, {"tpe": "critical"}), {})
    push.PUSH["update_policy"] = "new_counties"

    out += ["", "== 三、訊息組裝 =="]
    counties = ["tpe", "nwt", "kee", "tao", "hsz", "ila", "hua"]
    msgs = push.build_messages(alert(counties=counties), {c: "critical" for c in counties})
    check("7 個縣市 × 3 語 → 每語 2 則（5＋2），共 6 則", len(msgs), 6)
    check("condition 格式與主題名", msgs[0].condition.split(" || ")[0], "'alert_hsz_critical_zh' in topics")
    check("一則 condition 最多 5 個主題", max(m.condition.count(" in topics") for m in msgs), 5)
    check("payload 只放 uid／title／level", sorted(msgs[0].data), ["level", "title", "uid"])
    check("Android tag＝uid", msgs[0].android.notification.tag, "TEST_uid_1")
    check("Android 通知頻道 major_alerts", msgs[0].android.notification.channel_id, "major_alerts")
    check("測試主題前綴 test_", push.build_messages(alert(), {"tpe": "critical"}, prefix="test")[0].condition,
          "'test_tpe_critical_zh' in topics")
    check("APNs collapse-id＝uid", msgs[0].apns.headers["apns-collapse-id"], "TEST_uid_1")
    check("webpush tag＝uid", msgs[0].webpush.notification.tag, "TEST_uid_1")
    check("Android 高優先、TTL 為正", (msgs[0].android.priority, msgs[0].android.ttl.total_seconds() > 0), ("high", True))
    langs = {m.condition.split("'")[1].rsplit("_", 1)[1]: m for m in msgs}
    check("英文 critical 標題與 App 等級譯名一致", langs["en"].notification.title, "Critical alert")
    check("日文內文用日文摘要", langs["ja"].notification.body, "台北市で大雨")
    long_uid = "X" * 70
    check("uid 超過 64 位元組 → sha256 前 32 碼", len(push.collapse_key(long_uid)), 32)
    check("有 extreme 時標題用 extreme", push.build_messages(alert(), {"tpe": "extreme"})[0].notification.title, "極重大示警")
    check("內文不超過 200 字", len(push.build_messages(alert(ai_summary="長" * 500), {"tpe": "critical"})[0].notification.body), 200)

    out += ["", "== 四、Firestore 交易去重（push_sent_test，跑完刪除） =="]
    if not firebase_admin._apps:
        firebase_admin.initialize_app(options={"projectId": "ai-watchtower-tw"})
    db = firestore.client()
    push.PUSH["collection"] = "push_sent_test"
    push.PUSH["cooldown_collection"] = "push_cooldown_test"
    clear_cool = lambda: [d.reference.delete() for d in db.collection(push._cool_coll()).stream()]
    clear_cool()
    pl = lambda a: push.plan(db, a)[:2]
    ids = []
    try:
        a1 = alert(uid="TEST_chain_A", cap_identifier="TEST-CAP-A", counties=["tpe"])
        a2 = alert(uid="TEST_chain_B", cap_identifier="TEST-CAP-B", cap_msg_type="Update",
                   cap_references=["TEST-CAP-A"], counties=["tpe", "ila"])
        a3 = alert(uid="TEST_chain_C", cap_identifier="TEST-CAP-C", cap_msg_type="Update",
                   cap_references=["TEST-CAP-A", "TEST-CAP-B"], counties=["tpe", "ila"])
        a4 = alert(uid="TEST_nocap", cap_identifier=None, counties=["kee"])
        ids = [push._doc_id(k) for k in ("cap:TEST-CAP-A", "cap:TEST-CAP-B", "cap:TEST-CAP-C", "uid:TEST_nocap")]
        check("第一份電文：推 tpe", pl(a1), ({"tpe": "critical"}, ""))
        check("更新電文新增 ila：只推 ila", pl(a2), ({"ila": "critical"}, ""))
        check("再一份更新、縣市沒變：不推", pl(a3), ({}, "already_pushed_in_chain"))
        check("同一份電文重複觸發：不推", pl(a2), ({}, "duplicate"))
        check("沒有電文 identifier：用 uid 去重，第一次推", pl(a4), ({"kee": "critical"}, ""))
        check("沒有電文 identifier：同 uid 第二次不推", pl(a4), ({}, "duplicate"))
        rec = db.collection(push._coll()).document(ids[2]).get().to_dict()
        check("鏈上最新一份記得整條鏈推過的縣市", sorted(rec["counties"]), ["ila", "tpe"])
    finally:
        coll = push._coll()
        for i in ids:
            db.collection(coll).document(i).delete()
        clear_cool()
        push.PUSH["collection"] = "push_sent"
    left = len(list(db.collection(coll).limit(5).stream()))
    check(f"{coll} 清乾淨", left, 0)
    check("dry_run 的去重紀錄在獨立集合", push._coll(), "push_sent_dryrun")
    push.PUSH["mode"] = "live"
    check("live 才寫正式集合 push_sent", push._coll(), "push_sent")
    push.PUSH["mode"] = "dry_run"

    out += ["", "== 五、maybe_push 日誌不含內文（FCM 替身） =="]

    class FakeResp:
        def __init__(self, n):
            self.responses = [type("R", (), {"success": True, "exception": None})() for _ in range(n)]
            self.success_count, self.failure_count = n, 0

    from firebase_admin import messaging
    saved_send, saved_plan = messaging.send_each, push.plan
    sent = {}
    messaging.send_each = lambda msgs, dry_run=False: (sent.update(n=len(msgs), dry=dry_run), FakeResp(len(msgs)))[1]
    push.plan = lambda db, doc: ({"tpe": "critical"}, "")
    try:
        buf = io.StringIO()
        with redirect_stdout(buf):
            r = push.maybe_push(None, alert(ai_summary="秘密內文ZQ1", ai_summary_en="secretZQ2"))
        log = buf.getvalue()
        check("dry_run 模式送出時 dry_run=True", (r["result"], sent.get("dry")), ("sent", True))
        check("日誌不含摘要內文", any(s in log for s in ("秘密內文ZQ1", "secretZQ2", "臺北市豪雨")), False)
        check("日誌只有一行 push 紀錄", [json.loads(l)["message"] for l in log.splitlines()], ["push"])
    finally:
        messaging.send_each, push.plan = saved_send, saved_plan

    out += ["", "== 六、發送失敗：重送一次，仍失敗就撤回占位（10/3 Codex 審稿） =="]

    def fake_send(fail_times):
        state = {"n": 0}

        def send(msgs, dry_run=False):
            state["n"] += 1
            bad_ = state["n"] <= fail_times
            r = type("R", (), {"success": not bad_, "exception": None if not bad_ else ConnectionError()})
            resp = type("Resp", (), {})()
            resp.responses = [r() for _ in msgs]
            resp.success_count = 0 if bad_ else len(msgs)
            resp.failure_count = len(msgs) if bad_ else 0
            return resp
        return send, state

    push.PUSH["collection"] = "push_sent_test"
    push.PUSH["cooldown_collection"] = "push_cooldown_test"
    push.PUSH["cooldown_minutes"] = 0
    coll = push._coll()
    a5 = alert(uid="TEST_fail_A", cap_identifier="TEST-CAP-FAIL", counties=["tpe"])
    fid = push._doc_id("cap:TEST-CAP-FAIL")
    import time as _time
    saved_sleep = _time.sleep
    _time.sleep = lambda s: None
    try:
        messaging.send_each, st = fake_send(1)
        with redirect_stdout(io.StringIO()):
            r = push.maybe_push(db, a5)
        check("暫時失敗、重送成功：結果 sent、送了兩次", (r["result"], st["n"]), ("sent", 2))
        check("重送成功：占位保留", db.collection(coll).document(fid).get().exists, True)
        db.collection(coll).document(fid).delete()
        messaging.send_each, st = fake_send(99)
        buf = io.StringIO()
        with redirect_stdout(buf):
            r = push.maybe_push(db, a5)
        check("重送後仍失敗：結果 failed_released", r["result"], "failed_released")
        check("重送後仍失敗：占位已撤回", db.collection(coll).document(fid).get().exists, False)
        check("失敗日誌記錯誤類別", json.loads(buf.getvalue().splitlines()[-1])["errors"], ["ConnectionError"])
        messaging.send_each, st = fake_send(0)
        with redirect_stdout(io.StringIO()):
            r = push.maybe_push(db, a5)
        check("撤回後下一次觸發可以重推", (r["result"], r.get("counties")), ("sent", 1))

        def boom(msgs, dry_run=False):
            raise RuntimeError("x")
        db.collection(coll).document(fid).delete()
        messaging.send_each = boom
        with redirect_stdout(io.StringIO()):
            r = push.maybe_push(db, a5)
        check("整批送不出去（例外）：也撤回占位", (r["result"], db.collection(coll).document(fid).get().exists),
              ("failed_released", False))
    finally:
        messaging.send_each = saved_send
        _time.sleep = saved_sleep
        db.collection(coll).document(fid).delete()
        push.PUSH["collection"] = "push_sent"
        push.PUSH["cooldown_minutes"] = 30

    out += ["", "== 七、冷卻（使用者 10/3 核准：同縣市＋同等級＋同類別 30 分鐘，extreme 不受限） =="]
    now = datetime.now(timezone.utc)
    ac = push.apply_cooldown
    check("沒有上次紀錄 → 推", ac({"pif": "critical"}, {"pif": None}, now), ({"pif": "critical"}, []))
    check("10 分鐘前推過 → 擋", ac({"pif": "critical"}, {"pif": now - timedelta(minutes=10)}, now), ({}, ["pif"]))
    check("31 分鐘前推過 → 推", ac({"pif": "critical"}, {"pif": now - timedelta(minutes=31)}, now), ({"pif": "critical"}, []))
    check("extreme 不受冷卻", ac({"pif": "extreme"}, {"pif": now - timedelta(minutes=1)}, now), ({"pif": "extreme"}, []))
    check("部分縣市被擋", ac({"pif": "critical", "ila": "critical"}, {"pif": now - timedelta(minutes=5), "ila": None}, now),
          ({"ila": "critical"}, ["pif"]))
    push.PUSH["cooldown_minutes"] = 60
    check("分鐘數是設定（60 分鐘時 31 分鐘前推過 → 擋）",
          ac({"pif": "critical"}, {"pif": now - timedelta(minutes=31)}, now), ({}, ["pif"]))
    push.PUSH["cooldown_minutes"] = 30
    push.PUSH["collection"], push.PUSH["cooldown_collection"] = "push_sent_test", "push_cooldown_test"
    keys = []
    try:
        mk = lambda uid, ident, cat, counties, lvl="critical": alert(uid=uid, cap_identifier=ident, raw_category=cat,
                                                                    counties=counties, severity=lvl)
        b1 = mk("TEST_cool_1", "TEST-COOL-1", "雷雨", ["pif"])
        b2 = mk("TEST_cool_2", "TEST-COOL-2", "雷雨", ["pif", "ila"])
        b3 = mk("TEST_cool_3", "TEST-COOL-3", "降雨", ["pif"])
        b4 = mk("TEST_cool_4", "TEST-COOL-4", "雷雨", ["pif"], "extreme")
        b5 = mk("TEST_cool_5", "TEST-COOL-5", "雷雨", ["pif"])
        keys = ["cap:TEST-COOL-%d" % i for i in range(1, 6)]
        check("第一則雷雨：推 pif", push.plan(db, b1), ({"pif": "critical"}, "", []))
        check("同類別第二則：pif 被擋、ila 推", push.plan(db, b2), ({"ila": "critical"}, "", ["pif"]))
        check("不同類別（降雨）：推", push.plan(db, b3), ({"pif": "critical"}, "", []))
        check("extreme：照推", push.plan(db, b4), ({"pif": "extreme"}, "", []))
        check("全部被擋：reason=cooldown", push.plan(db, b5), ({}, "cooldown", ["pif"]))
        rec = db.collection(push._coll()).document(push._doc_id(keys[1])).get().to_dict()
        check("被冷卻擋下的不算推過（covered 只有 ila）", (sorted(rec["counties"]), rec["cooldown_blocked"]), (["ila"], ["pif"]))
        b6 = mk("TEST_cool_6", "TEST-COOL-6", "強風", ["kee"])
        keys.append("cap:TEST-COOL-6")
        cid = push._cool_id("kee", "critical", "強風")
        messaging.send_each, _ = fake_send(99)
        _time.sleep = lambda s: None
        with redirect_stdout(io.StringIO()):
            r = push.maybe_push(db, b6)
        check("發送失敗：冷卻紀錄一併撤回", (r["result"], db.collection(push._cool_coll()).document(cid).get().exists),
              ("failed_released", False))
        buf = io.StringIO()
        messaging.send_each, _ = fake_send(0)
        with redirect_stdout(buf):
            push.maybe_push(db, mk("TEST_cool_7", "TEST-COOL-7", "雷雨", ["pif"]))
        keys.append("cap:TEST-COOL-7")
        rec = json.loads(buf.getvalue().splitlines()[-1])
        check("日誌記 reason=cooldown 與被擋縣市數", (rec["result"], rec["reason"], rec["cooldown"]), ("skip", "cooldown", 1))
    finally:
        messaging.send_each = saved_send
        _time.sleep = saved_sleep
        for k in keys:
            db.collection(push._coll()).document(push._doc_id(k)).delete()
        for d in db.collection(push._cool_coll()).stream():
            d.reference.delete()
        left = len(list(db.collection(push._cool_coll()).limit(5).stream()))
        push.PUSH["collection"], push.PUSH["cooldown_collection"] = "push_sent", "push_cooldown"
    check("冷卻測試集合清乾淨", left, 0)

    out.append(f"\n不符 {bad}")
    text = "\n".join(out)
    print(text)
    LOG.write_text(text + "\n", encoding="utf-8")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
