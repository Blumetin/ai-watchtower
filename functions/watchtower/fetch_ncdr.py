#!/usr/bin/env python3
import json
import sys
import time
import urllib.error
import urllib.request

FEED_URL = "https://alerts.ncdr.nat.gov.tw/JSONAtomFeed.ashx"
RETRY_WAITS = (25, 30)
BUDGET = 75


def open_with_retry(req, timeout: int = 20, opener=None, waits=RETRY_WAITS, budget: float = BUDGET):
    start = time.monotonic()
    for k in range(len(waits) + 1):
        try:
            return (opener.open if opener else urllib.request.urlopen)(req, timeout=timeout)
        except urllib.error.HTTPError as e:
            if e.code != 429 and e.code < 500 or k == len(waits):
                raise
            ra = (e.headers or {}).get("Retry-After", "")
            wait = min(int(ra), 30) if str(ra).isdigit() else waits[k]
            if time.monotonic() - start + wait + timeout > budget:
                raise
            print(json.dumps({"severity": "WARNING", "message": "ncdr_retry", "code": e.code, "wait": wait, "attempt": k + 1}))
            time.sleep(wait)


def fetch_alerts(alert_type: str | None = None) -> list[dict]:
    url = FEED_URL if alert_type is None else f"{FEED_URL}?AlertType={alert_type}"
    req = urllib.request.Request(url, headers={"User-Agent": "disaster-assistant/0.1"})
    with open_with_retry(req) as resp:
        feed = json.load(resp)

    entries = feed.get("entry", [])
    if isinstance(entries, dict):
        entries = [entries]

    alerts = []
    for e in entries:
        summary = e.get("summary", {})
        link = e.get("link", {})
        if isinstance(link, list):
            link = link[0] if link else {}
        alerts.append({
            "id": e.get("id"),
            "category": e.get("category", {}).get("@term", ""),
            "title": e.get("title"),
            "updated": e.get("updated"),
            "sender": e.get("author", {}).get("name", ""),
            "summary": summary.get("#text", "") if isinstance(summary, dict) else str(summary),
            "cap_link": link.get("@href", "") if isinstance(link, dict) else "",
            "expires": e.get("expires", ""),
        })
    return alerts


if __name__ == "__main__":
    alert_type = sys.argv[1] if len(sys.argv) > 1 else None
    alerts = fetch_alerts(alert_type)
    print(json.dumps(alerts, ensure_ascii=False, indent=2))
    print(f"\n共 {len(alerts)} 筆示警", file=sys.stderr)
