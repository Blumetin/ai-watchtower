import json
from datetime import datetime, timedelta, timezone

KEEP_DAYS = 60


def hourly_sources(db, hour_key: str) -> tuple[int, int]:
    ask_set, rep_set = set(), set()
    for snap in db.collection("rate_limits").select([]).stream():
        head, _, hk = snap.id.rpartition("_")
        if hk != hour_key or head == "report_daily":
            continue
        (rep_set if head.startswith("report_") else ask_set).add(head)
    counts = (len(ask_set), len(rep_set))
    ask_set.clear()
    rep_set.clear()
    return counts


def record_previous_hour(db, now: datetime | None = None) -> str:
    from google.cloud import firestore as gfs

    now = now or datetime.now(timezone.utc)
    hour_key = (now.astimezone(timezone.utc) - timedelta(hours=1)).strftime("%Y%m%d%H")
    ask_n, report_n = hourly_sources(db, hour_key)
    db.collection("usage_hourly").document(hour_key).set(
        {"ask": ask_n, "report": report_n, "counted_at": gfs.SERVER_TIMESTAMP,
         "expire_at": now + timedelta(days=KEEP_DAYS)})
    print(json.dumps({"severity": "INFO", "message": "usage_hourly written", "hour": hour_key}))
    return hour_key
