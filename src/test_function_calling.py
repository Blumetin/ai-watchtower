import json
import os
import time
from datetime import datetime, timedelta

from google import genai

from fetch_ncdr import fetch_alerts
from normalize import pipeline
from test_cwa import cwa_get, flatten

MODEL = os.environ.get("TEST_MODEL", "gemini-3.1-flash-lite")
PAUSE = 1
MAX_RETURN = 8

client = genai.Client()

ACTIVE = [a for a in pipeline(fetch_alerts()) if a.status == "active"]


def get_active_alerts(county: str | None = None, group: str | None = None,
                      category: str | None = None) -> dict:
    hits = ACTIVE
    if group:
        hits = [a for a in hits if a.group == group]
    if category:
        hits = [a for a in hits if a.raw_category == category]
    if county:
        names = {county, county.replace("臺", "台"), county.replace("台", "臺")}
        hits = [a for a in hits if any(n in a.title + a.summary for n in names)]
    return {
        "total": len(hits),
        "alerts": [{"group": a.group, "category": a.raw_category, "sender": a.sender,
                    "updated": a.updated.isoformat(), "summary": a.summary[:120]}
                   for a in hits[:MAX_RETURN]],
    }


def get_recent_quakes(days: int = 7, min_magnitude: float = 0) -> dict:
    since = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%dT%H:%M:%S")
    data = cwa_get("E-A0015-001", timeFrom=since)
    quakes = [flatten(eq) for eq in data["records"]["Earthquake"]]
    quakes = [q for q in quakes if q["magnitude"] >= min_magnitude]
    return {"total": len(quakes), "quakes": quakes}


SYSTEM = """你是臺灣防災速報 App 的問答助理。
規則：
- 除了地震預測的問題之外，回答示警或地震的問題前，一定要先呼叫工具查詢，不得憑記憶回答。
- 只能根據工具回傳的內容回答，不得補充工具沒有回傳的資訊或建議。
- get_active_alerts 回傳 total 為 0 時，回覆「目前查不到相關的生效示警」，不得說成當地沒有示警（查詢方式可能有遺漏），也不得自行編寫示警內容。
- get_recent_quakes 回傳 total 為 0 時，說明查詢的天數與規模門檻，回覆查不到符合條件的地震。
- total 大於實際列出的則數時，要先說明總共有幾則，再說明以下只列出最新的幾則。
- 使用者問到地震預測（例如「明天會不會地震」）時，不呼叫工具，回覆：目前的科學無法預測地震發生的時間與地點，建議平時做好防災準備。
- 回答簡短，用一般民眾看得懂的話。"""

QUESTIONS = [
    "屏東現在有什麼警報？",
    "最近有比較大的地震嗎",
    "全臺的停水資訊",
    "連江縣現在有什麼警報？",
    "明天會不會地震？",
]


def ask(question: str) -> None:
    for attempt in range(3):
        try:
            resp = client.models.generate_content(
                model=MODEL,
                contents=question,
                config={"tools": [get_active_alerts, get_recent_quakes],
                        "system_instruction": SYSTEM},
            )
            break
        except genai.errors.ServerError:
            if attempt == 2:
                raise
            time.sleep(20)
    time.sleep(PAUSE)
    print(f"\n===== 問：{question}")
    calls = []
    for content in resp.automatic_function_calling_history or []:
        for part in content.parts or []:
            if part.function_call:
                args = ", ".join(f"{k}={v!r}" for k, v in part.function_call.args.items())
                calls.append(f"{part.function_call.name}({args})")
            if part.function_response:
                result = part.function_response.response.get("result", {})
                calls.append(f"  → 回傳 total={result.get('total')}")
    print("呼叫：", "（沒有呼叫工具）" if not calls else "")
    for c in calls:
        print("  ", c)
    print("答：", resp.text.strip())


if __name__ == "__main__":
    print(f"生效中示警 {len(ACTIVE)} 筆（{datetime.now():%Y-%m-%d %H:%M} 下載）")
    for q in QUESTIONS:
        ask(q)
