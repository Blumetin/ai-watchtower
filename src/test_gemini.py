import os
import sys
import time
from enum import Enum

from google import genai
from pydantic import BaseModel

REPORT = """發震時間：2026年8月22日11時40分15秒
震央位置：北緯24.42度、東經121.99度，宜蘭縣政府東南方41.7公里（位於臺灣東部海域）
芮氏規模：5.1
地震深度：27.8公里
各地最大震度：宜蘭縣3級、花蓮縣3級、新北市2級、桃園市2級、臺中市2級、南投縣2級、新竹縣2級、臺北市2級、彰化縣2級、基隆市1級、苗栗縣1級、新竹市1級、嘉義縣1級、雲林縣1級、嘉義市1級
官方severity：Minor　alert_color：綠色"""

PROMPT_V1 = f"把這則地震報告改寫成白話文。\n\n地震報告：\n{REPORT}"

PROMPT_V2 = (f"把這則地震報告改寫成白話文。只能使用報告中出現的資訊，不得推測或補充。"
             f"\n\n地震報告：\n{REPORT}")

PROMPT_V3 = f"""你是臺灣防災速報編輯。將官方地震報告改寫成給一般民眾的速報。

規則：
- 60 字以內，一段文字，不用條列
- 依序包含：發震時間、震央位置、規模、最大震度與地區
- 震度只寫最大震度與其縣市，其餘縣市不列
- 只能使用報告中出現的資訊，不得推測或補充
- 語氣冷靜清楚，不使用驚嘆號
- 若報告中有「無海嘯威脅」等官方判定，必須保留

地震報告：
{REPORT}"""

PROMPT_V4 = PROMPT_V3.replace("- 若報告中有「無海嘯威脅」等官方判定，必須保留\n", "")
assert PROMPT_V4 != PROMPT_V3

PROMPT_V3B = PROMPT_V3.replace(
    "- 若報告中有「無海嘯威脅」等官方判定，必須保留\n",
    "- 報告中沒有提到的事項一律不寫；報告中若有官方的判定文字，照原文保留\n")
REPORT_WITH_TSUNAMI = REPORT + "\n海嘯：本地震無海嘯威脅"

MODEL = os.environ.get("TEST_MODEL", "gemini-3.1-flash-lite")
PAUSE = 1
client = genai.Client()


def run(label: str, prompt: str, temperature: float | None = 0.2):
    config = {} if temperature is None else {"temperature": temperature}
    resp = client.models.generate_content(
        model=MODEL, contents=prompt, config=config)
    time.sleep(PAUSE)
    text = resp.text.strip()
    print(f"--- {label}｜溫度 {temperature}（{len(text)} 字）---")
    print(text)
    print()



class Severity(str, Enum):
    critical = "critical"
    warning = "warning"
    info = "info"


class AlertAssessment(BaseModel):
    severity: Severity
    affected_areas: list[str]
    action_advice: str
    reason: str


GRADING_RULES_V1 = """你是臺灣防災警報分級器。依下表評估示警嚴重度：
地震海嘯：最大震度5弱以上或伴隨海嘯警報=critical；最大震度4級=warning；3級以下=info
氣象：颱風陸上警報、大豪雨特報=critical；豪雨、強風、高溫特報=warning；一般天氣提醒=info
水利：水庫緊急洩洪、淹水警戒紅色=critical；水庫放流、淹水感測、土石流黃色警戒=warning；區排警戒=info
火災事故：大規模火災、疏散避難=critical；一般火災通報=warning；消防安檢不合格=info
交通：重大鐵路事故=critical；主要幹道封閉=warning；一般封閉=info
民生：大規模停班停課=critical；整區停水=warning；局部停水、森林遊樂區公告=info"""


GRADING_RULES = """你是臺灣防災警報分級器。依下表評估示警嚴重度：
地震海嘯：最大震度5弱以上或伴隨海嘯警報=critical；最大震度4級=warning；3級以下=info
氣象：颱風陸上警報、大豪雨特報=critical；豪雨、強風、高溫特報=warning；一般天氣提醒=info
水利：水庫緊急洩洪、淹水警戒紅色、土石流紅色警戒=critical；水庫放流、淹水感測、土石流黃色警戒=warning；區排警戒=info
火災事故：大規模火災、疏散避難=critical；一般火災通報=warning；消防安檢不合格=info
交通：重大鐵路事故=critical；主要幹道封閉=warning；一般封閉=info
民生：大規模停班停課=critical；整區停水=warning；局部停水、森林遊樂區公告=info

欄位規則：
- affected_areas：地震只列最大震度所在的縣市；其他示警列出原文提到的地區。
- action_advice：只能摘錄示警原文中已有的行動指示，20 字以內；原文沒有行動指示時填空字串，不得自行補充建議。
- reason：寫出依據上表的哪一條。"""


def assess(alert_text: str, rules: str = GRADING_RULES) -> AlertAssessment:
    resp = client.models.generate_content(
        model=MODEL,
        contents=f"{rules}\n\n評估這則臺灣防災示警的嚴重度：\n{alert_text}",
        config={
            "response_mime_type": "application/json",
            "response_schema": AlertAssessment,
        },
    )
    time.sleep(PAUSE)
    return resp.parsed


CAP_TO_LEVEL = {"Extreme": "critical", "Severe": "critical",
                "Moderate": "warning", "Minor": "info"}


def grade(alert_text: str, cap_severity: str | None = None) -> tuple[str, str]:
    if cap_severity in CAP_TO_LEVEL:
        return CAP_TO_LEVEL[cap_severity], "官方等級"
    return assess(alert_text).severity.value, "AI 判定"


def day8():
    print("========== Day 8：四輪 prompt 實測 ==========\n")
    run("第一版（太自由）", PROMPT_V1)
    run("第二版（加限制）", PROMPT_V2)
    for n in range(5):
        run(f"第三版（加格式與規則）#{n + 1}", PROMPT_V3)
    for n in range(5):
        run(f"第三版（加格式與規則）預設溫度 #{n + 1}", PROMPT_V3, temperature=None)
    for n in range(5):
        run(f"未採用的修法 #{n + 1}", PROMPT_V3B)
    for n in range(5):
        run(f"未採用的修法＋輸入含海嘯判定 #{n + 1}",
            PROMPT_V3B.replace(REPORT, REPORT_WITH_TSUNAMI))
    for n in range(5):
        run(f"第四版（定稿）#{n + 1}", PROMPT_V4)
    for n in range(5):
        run(f"第四版（定稿）預設溫度 #{n + 1}", PROMPT_V4, temperature=None)



def day9():
    print("========== Day 9：Structured Output 分級 ==========\n")
    cases = [
        ("8/22 M5.1 地震", REPORT),
        ("水庫放流", "石門水庫於今日14時起調節性放流，下游河道請勿逗留。"),
        ("土石流紅色警戒", "花蓮縣秀林鄉土石流紅色警戒，請立即撤離保全對象。"),
    ]
    for title, rules in [("第一輪（修正前）", GRADING_RULES_V1),
                         ("第二輪（修正後）", GRADING_RULES)]:
        print(f"--- {title} ---")
        for name, text in cases:
            for n in range(3):
                print(name, f"#{n + 1}", assess(text, rules).model_dump_json())
        print()

    print("--- 官方等級優先 ---")
    print("8/22 地震（CAP severity=Minor）→", grade(REPORT, "Minor"))
    print("水庫放流（沒有官方等級）→", grade(cases[1][1]))


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "all"
    if target in ("day8", "all"):
        day8()
    if target in ("day9", "all"):
        day9()
