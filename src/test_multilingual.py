import os
import re
import time

from google import genai
from pydantic import BaseModel

MODEL = os.environ.get("TEST_MODEL", "gemini-3.1-flash-lite")
PAUSE = 1
client = genai.Client()


class MultilingualAlert(BaseModel):
    zh: str
    en: str
    ja: str


ALERTS = [
    "2026年8月22日11時40分，臺灣東部海域發生規模5.1地震，宜蘭縣與花蓮縣最大震度3級。",
    "（測試文字）2026年9月21日14時30分，嘉義縣發生規模6.1地震，嘉義縣與臺南市最大震度5弱。",
    "（測試文字）中央氣象署發布豪雨特報：屏東縣山區今日有局部豪雨，24小時累積雨量可能達200毫米，請注意坍方與落石。",
]

BASE = """把下面這則臺灣的防災速報寫成三種語言：繁體中文（原文照用）、英文、日文。
規則：
- 時間、地點、數字必須和原文完全一致，不得增加或省略資訊。
- 原文的語氣強弱要保留：「可能」不得寫成「預計」或「將會」。
- 原文是預報（例如「今日有」「可能」）就維持預報語氣，不得寫成正在發生。
- 日文用です・ます体，兩則之間文體要一致。
- 依各語言的習慣表達，不必逐字翻譯。"""

GLOSSARY_ITEMS = [
    (("規模",), "規模＝magnitude／マグニチュード；規模後面不加「級」。"),
    (("震度",), "震度＝intensity／震度。臺灣的震度分級和日本不同，日文版第一次出現震度時加註「（台湾の震度階級）」；"
               "英文版的寫法依下方「英文版的寫法」。"),
    (("5弱", "5強", "6弱", "6強"), "震度 5弱、5強、6弱、6強的英文照中央氣象署寫成 \"5 Lower\"、\"5 Upper\"、\"6 Lower\"、\"6 Upper\"。"
                                 "日文寫「5弱」「5強」。"),
    (("大雨", "豪雨"), "雨量分級的英文照中央氣象署：大雨 Heavy Rain、豪雨 Extremely Heavy Rain、大豪雨 Torrential Rain、"
                     "超大豪雨 Extremely Torrential Rain。日文照臺灣用語寫「豪雨」「大雨」，不要寫成日本氣象廳的雨量強度用語。"),
    (("特報",), "特報＝Advisory／特報。"),
    (("縣", "市"), "縣市名稱：英文用官方拼音加 County／City（例如 Yilan County、Tainan City）；"
                  "日文用漢字加「県／市」（宜蘭県、台南市）。"
                  "「縣」和「市」照原文，不得互換：原文是花蓮縣就是 Hualien County／花蓮県，不是花蓮市。"),
    (("中央氣象署",), "中央氣象署＝Central Weather Administration (CWA)／中央気象署。"),
]


INTENSITY_WORDS = {"3": "light shaking", "4": "moderate shaking", "5 Lower": "strong shaking",
                   "5 Upper": "strong shaking", "6 Lower": "violent shaking",
                   "6 Upper": "violent shaking", "7": "extreme shaking"}
EN_RULES = """
英文版的寫法（必須遵守）：
- 時間寫成 24 小時制加日期，後面標時區：例如 "11:40 on August 22, 2026 (Taiwan time, UTC+8)"。
- 震度寫成 "intensity 3 (light shaking) on Taiwan's intensity scale"；描述詞對照：3 light shaking、4 moderate shaking、5 Lower／5 Upper strong shaking、6 Lower／6 Upper violent shaking、7 extreme shaking。
- 只有原文是「特報」時，英文版第一行才先寫一句大寫的白話標題（地震報告等其他速報不加標題），格式「HAZARD: 影響＋時間」，例如 "EXTREMELY HEAVY RAIN: Up to 200 mm of rain possible in 24 hours in the Pingtung County mountains today."，換行後再寫特報的正式內容；特報的產品名稱照中央氣象署英文寫。
- 雨量只寫公釐（mm），不要自行換算成英寸。"""


def add_imperial(text: str) -> str:
    return re.sub(r"(\d+(?:\.\d+)?) mm\b",
                  lambda m: f"{m.group(1)} mm (about {float(m.group(1)) / 25.4:.0f} in)", text)


def glossary_for(text: str) -> str:
    rules = [rule for keys, rule in GLOSSARY_ITEMS if any(k in text for k in keys)]
    return "\n術語與地名規則（必須遵守）：\n" + "\n".join(f"- {r}" for r in rules) if rules else ""


TEST_TAG = "（測試文字）"
TAGS = {"zh": "（測試文字）", "en": "(Test message) ", "ja": "（テスト）"}


def generate(alert: str, with_glossary: bool, tag_by_code: bool = False) -> MultilingualAlert:
    tagged = tag_by_code and alert.startswith(TEST_TAG)
    body = alert[len(TEST_TAG):] if tagged else alert
    prompt = BASE + (glossary_for(body) + EN_RULES if with_glossary else "") + f"\n\n速報：\n{body}"
    resp = client.models.generate_content(
        model=MODEL, contents=prompt,
        config={"response_mime_type": "application/json",
                "response_schema": MultilingualAlert})
    time.sleep(PAUSE)
    out = resp.parsed
    if tagged:
        for lang, tag in TAGS.items():
            setattr(out, lang, tag + getattr(out, lang))
    return out


MONTHS = {m: str(i + 1) for i, m in enumerate(
    ["January", "February", "March", "April", "May", "June", "July",
     "August", "September", "October", "November", "December"])}


def numbers(text: str) -> list[str]:
    for name, num in MONTHS.items():
        text = re.sub(rf"\b{name}\b", num, text)
    text = re.sub(r"UTC[+-]\d+", "", text)
    return sorted(re.findall(r"\d+(?:\.\d+)?", text))


JA_COUNTY = {"臺": "台"}


def check_counties_ja(source: str, ja: str) -> list[str]:
    bad = []
    for name, kind in re.findall(r"([\u4e00-\u9fff]{2})(縣|市)", source):
        ja_name = "".join(JA_COUNTY.get(ch, ch) for ch in name)
        expect = ja_name + ("県" if kind == "縣" else "市")
        if expect not in ja:
            bad.append(f"{name}{kind}→應為 {expect}")
    return bad


def check_numbers(source: str, out: MultilingualAlert) -> dict:
    want = numbers(source)
    return {lang: numbers(getattr(out, lang)) == want for lang in ("zh", "en", "ja")}


def back_translate(text: str) -> str:
    resp = client.models.generate_content(
        model=MODEL,
        contents=f"把下面這段文字逐句直譯成繁體中文，不要潤飾、不要補充：\n{text}")
    time.sleep(PAUSE)
    return resp.text.strip()


if __name__ == "__main__":
    for title, flag in [("沒有術語表", False), ("有術語表（只附用得到的條目），標記由程式處理", True)]:
        print(f"\n########## {title}")
        for alert in ALERTS:
            out = generate(alert, flag, tag_by_code=flag)
            print(f"\n原文：{alert}")
            for lang in ("en", "ja"):
                print(f"  {lang}: {getattr(out, lang)}")
            result = check_numbers(alert, out)
            print("  數字核對：", result, "" if all(result.values()) else "→ 不通過")
            print("  日文縣市核對：", check_counties_ja(alert, out.ja) or "通過")
            if flag:
                out.en = add_imperial(out.en)
                print("  en（加上英制換算後）:", out.en)
            if flag:
                print("  日文翻回中文：", back_translate(out.ja))
