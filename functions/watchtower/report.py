from datetime import datetime, timedelta, timezone

from firebase_admin import firestore

REPORT_REASONS = {"incorrect", "outdated", "offensive", "other"}
REPORT_ROUTES = {"crisis", "crisis_check", "prediction", "emotion", "tools", "knowledge", "tools→knowledge", "error"}
REPORT_LIMITS = {"question": 300, "answer": 8000, "note": 200}
REPORT_KEEP_DAYS = 90
REPORT_DAILY_CAP = 500


def parse_report(data) -> tuple[dict, dict, bool]:
    data = data if isinstance(data, dict) else {}
    report = {k: str(data.get(k) or "").strip() for k in ("question", "answer", "note", "reason", "lang", "route")}
    ok = (bool(report["question"]) and bool(report["answer"]) and report["reason"] in REPORT_REASONS
          and report["lang"] in ("zh", "en", "ja")
          and all(len(report[k]) <= n for k, n in REPORT_LIMITS.items()))
    report["route"] = report["route"] if report["route"] in REPORT_ROUTES else "unknown"
    return report, {k: len(report[k]) for k in REPORT_LIMITS}, ok


def over_daily_cap(db) -> tuple[bool, int]:
    day = datetime.now(timezone(timedelta(hours=8))).strftime("%Y%m%d")
    ref = db.collection("rate_limits").document(f"report_daily_{day}")
    ref.set({"n": firestore.Increment(1), "expire_at": datetime.now(timezone.utc) + timedelta(days=2)}, merge=True)
    n = ref.get().to_dict().get("n", 0)
    return n > REPORT_DAILY_CAP, n
