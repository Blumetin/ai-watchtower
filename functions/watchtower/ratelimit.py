import hashlib
import hmac
import json
import secrets
import time
from datetime import datetime, timedelta, timezone

TW = timezone(timedelta(hours=8))

_FALLBACK = secrets.token_hex(32)
_pepper = {"value": None, "at": 0.0}


def daily(base: str, day: str) -> str:
    return hmac.new(base.encode(), day.encode(), hashlib.sha256).hexdigest()


def tw_day(now: datetime | None = None) -> str:
    return (now or datetime.now(TW)).astimezone(TW).strftime("%Y%m%d")


def ip_pepper(db, now: datetime | None = None) -> str:
    if _pepper["value"] is None or time.time() - _pepper["at"] > 600:
        value, problem = "", None
        try:
            snap = db.collection("private_config").document("secrets").get()
            value = (snap.to_dict() or {}).get("ip_pepper", "") if snap.exists else ""
            problem = None if value else "Missing"
        except Exception as e:
            problem = type(e).__name__
        if problem:
            print(json.dumps({"severity": "WARNING", "message": "pepper_fallback", "error": problem}))
            value = _FALLBACK
        _pepper.update(value=value, at=time.time())
    return daily(_pepper["value"], tw_day(now))
