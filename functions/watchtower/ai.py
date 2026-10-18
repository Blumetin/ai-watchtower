import contextvars
import json
import os
import random
import re
import threading
import time
from enum import Enum

import httpx
from google import genai
from pydantic import BaseModel

from .cap import CAP_TO_LEVEL, COUNTY_I18N, COUNTY_NAMES, NAME_TO_CODE, official_red
from .rocdate import roc_in_output, to_gregorian

MODEL = "gemini-3.1-flash-lite"
SHORT_ENOUGH = 60

BACKEND = os.environ.get("GEMINI_BACKEND", "studio")
OTHER = {"studio": "vertex", "vertex": "studio"}

FAILOVER = os.environ.get("GEMINI_FAILOVER", "on") != "off"
FAILOVER_ASK = os.environ.get("GEMINI_FAILOVER_ASK", "off") == "on"
FAILOVER_COOLDOWN = 600
FAILOVER_CODES = {402, 429}
CALL_TIMEOUT_MS = 20_000
_bad_until: dict[str, float] = {}
_clients: dict[str, genai.Client] = {}
_used: contextvars.ContextVar[str] = contextvars.ContextVar("ai_backend_used", default=BACKEND)
_pin: contextvars.ContextVar[str | None] = contextvars.ContextVar("ai_backend_pin", default=None)
_client_lock = threading.Lock()


def _is_closed(c) -> bool:
    try:
        return bool(c._api_client._httpx_client.is_closed)
    except Exception:
        return False


def _new_client(backend: str) -> genai.Client:
    opts = {"timeout": CALL_TIMEOUT_MS}
    if backend == "vertex":
        return genai.Client(vertexai=True, location="global", http_options=opts,
                            project=os.environ.get("GOOGLE_CLOUD_PROJECT", "ai-watchtower-tw"))
    return genai.Client(http_options=opts)


def current_backend() -> str:
    if _pin.get():
        return _pin.get()
    if not (FAILOVER or FAILOVER_ASK):
        return BACKEND
    now = time.monotonic()
    if _bad_until.get(BACKEND, 0) > now and _bad_until.get(OTHER[BACKEND], 0) <= now:
        return OTHER[BACKEND]
    return BACKEND


def pin(backend: str | None) -> contextvars.Token:
    return _pin.set(backend)


def unpin(token: contextvars.Token) -> None:
    _pin.reset(token)


def client() -> genai.Client:
    backend = current_backend()
    _used.set(backend)
    c = _clients.get(backend)
    if c is not None and not _is_closed(c):
        return c
    with _client_lock:
        c = _clients.get(backend)
        if c is None or _is_closed(c):
            c = _clients[backend] = _new_client(backend)
        return c


def note_failure(category: str, err, scope: str = "enrich") -> bool:
    if not (FAILOVER_ASK if scope == "ask" else FAILOVER):
        return False
    if not (category in ("server", "transport") or category == "client" and err in FAILOVER_CODES):
        return False
    backend = _used.get()
    other = OTHER[backend]
    if _bad_until.get(other, 0) > time.monotonic():
        return False
    _bad_until[backend] = time.monotonic() + FAILOVER_COOLDOWN
    print(json.dumps({"severity": "WARNING", "message": "gemini_failover", "from": backend, "to": other,
                      "error": err, "scope": scope}))
    return True


def log_call(kind: str, model: str, resp=None, error: Exception | None = None, chars: int = 0) -> None:
    rec = {"severity": "INFO", "message": "gemini_call", "kind": kind, "model": model, "backend": _used.get()}
    if error is not None:
        rec.update(severity="WARNING", error=getattr(error, "code", None) or type(error).__name__)
    else:
        u = getattr(resp, "usage_metadata", None)
        if u:
            rec["in"] = u.prompt_token_count or 0
            rec["out"] = (u.candidates_token_count or 0) + (u.thoughts_token_count or 0)
        if chars:
            rec["chars"] = chars
    print(json.dumps(rec, ensure_ascii=False))
    if rec.get("error") == 402:
        print(json.dumps({"severity": "ERROR", "message": "GEMINI_402_ALERT", "backend": rec["backend"],
                          "detail": "Gemini API 預付額度用完；備援開著時加值改走 Vertex，仍請補 Gemini API 預付額度"}, ensure_ascii=False))


def backoff(attempt: int) -> None:
    time.sleep(5 * (attempt + 1) + random.uniform(0, 2))


AI_CALL_TIMEOUT = 20
MIN_CALL_SECONDS = 10
_deadline: contextvars.ContextVar[float | None] = contextvars.ContextVar("ai_deadline", default=None)


class AIBudgetExceeded(Exception):
    pass


def set_budget(seconds: float | None) -> contextvars.Token:
    return _deadline.set(None if seconds is None else time.monotonic() + seconds)


def reset_budget(token: contextvars.Token) -> None:
    _deadline.reset(token)


def _remaining() -> float | None:
    d = _deadline.get()
    return None if d is None else d - time.monotonic()


def _check_budget(kind: str, need: float = 0.0) -> None:
    left = _remaining()
    if left is not None and left - need < MIN_CALL_SECONDS:
        print(json.dumps({"severity": "WARNING", "message": "ai_budget_exceeded", "kind": kind,
                          "left": round(left, 1)}))
        raise AIBudgetExceeded()


def _retry_wait(attempt: int, kind: str) -> None:
    wait = 5 * (attempt + 1) + random.uniform(0, 2)
    _check_budget(kind, need=wait)
    time.sleep(wait)


def _generate(contents: str, config: dict, kind: str = "enrich"):
    for attempt in range(3):
        _check_budget(kind)
        left = _remaining()
        cfg = config if left is None else {**config, "http_options": {"timeout": int(min(AI_CALL_TIMEOUT, left) * 1000)}}
        try:
            resp = client().models.generate_content(model=MODEL, contents=contents, config=cfg)
            log_call(kind, MODEL, resp)
            return resp
        except genai.errors.ServerError as e:
            log_call(kind, MODEL, error=e)
            switched = note_failure("server", e.code)
            if attempt == 2:
                raise
            if not switched:
                _retry_wait(attempt, kind)
        except genai.errors.ClientError as e:
            log_call(kind, MODEL, error=e)
            switched = note_failure("client", e.code)
            if e.code != 429 and not switched or attempt == 2:
                raise
            if not switched:
                _retry_wait(attempt, kind)
        except httpx.TransportError as e:
            log_call(kind, MODEL, error=e)
            note_failure("transport", type(e).__name__)
            if attempt == 2:
                raise
        except RuntimeError as e:
            log_call(kind, MODEL, error=e)
            if attempt >= 1:
                raise



SUMMARY_PROMPT = """你是臺灣防災速報編輯。將官方示警改寫成給一般民眾的速報。

規則：
- 不超過 60 字（含標點），一段文字，不用條列
- 依序包含：發生什麼事、地點、時間；原文有行動指示時放在最後
- 行動指示照原文的說法寫，不得改寫成更具體的做法，也不得增加原文沒有的提醒
- 原文沒有行動指示時就不要寫行動指示，不得自行加上「請遠離…」「請注意…」「請留意…」這類勸告
- 只能使用示警中出現的資訊，不得推測或補充
- 語氣冷靜清楚，不使用驚嘆號

示警標題：{title}
發布單位：{sender}
內容：
{summary}"""


def tsunami_sentences(text: str) -> list[str]:
    return [s.strip() for s in re.split(r"(?<=[。；！？\n])", text) if "海嘯" in s and s.strip()]


ADVICE_RE = re.compile(r"(?:請|建議|務必|應儘速|應盡速|宜|切勿|勿|避免)[^，。；！？\n]{1,30}")
ADVICE_HEAD = re.compile(r"^(?:請|建議|務必|應儘速|應盡速|宜|切勿|勿|避免)(?:下游|附近|沿岸|轄內)?(?:民眾|居民|用戶|大家)?")
ADVICE_TAIL = re.compile(r"(?:以策安全|為宜|注意安全)$")


def _chars(t: str) -> str:
    return re.sub(r"[^\w]", "", t.replace("台", "臺")).replace("_", "")


def unsupported_advice(out: str, source: str) -> list[str]:
    src = _chars(source)
    bad = []
    for m in ADVICE_RE.finditer(out):
        core = ADVICE_TAIL.sub("", ADVICE_HEAD.sub("", m.group(0)))
        for piece in re.split(r"[、及與和並或]", core):
            p = _chars(piece)
            if len(p) < 2:
                continue
            grams = [p[i:i + 2] for i in range(len(p) - 1)]
            if sum(g in src for g in grams) / len(grams) < 0.5:
                bad.append(piece.strip())
    return bad


def _counties(text: str) -> set[str]:
    t = text.replace("台", "臺")
    return {n for n in COUNTY_NAMES.values() if n in t}


def source_front(summary: str, limit: int = 90) -> str:
    full = summary.strip()
    acc = ""
    for s in re.split(r"(?<=[。；])", full):
        if acc and len(acc) + len(s) > limit:
            break
        acc += s
    front = acc if len(acc) <= limit else acc[:limit] + "…"
    return front if _counties(full) <= _counties(front) else full


SUMMARY_WITH_INSTRUCTION = False


def summarize(title: str, sender: str, summary: str, instruction: str = "") -> tuple[str, str]:
    if len(summary) <= SHORT_ENOUGH:
        return summary, "原文"
    prompt = SUMMARY_PROMPT.format(title=title, sender=sender, summary=summary)
    if SUMMARY_WITH_INSTRUCTION and instruction:
        prompt += f"\n發布單位的指示：\n{instruction}"
    source = f"{title}\n{sender}\n{summary}\n{instruction}"
    text = _generate(prompt, {"temperature": 0.2}).text.strip()
    bad = unsupported_advice(text, source)
    if bad:
        print(json.dumps({"severity": "WARNING", "message": "summary_advice", "attempt": 1, "count": len(bad)}))
        text = _generate(prompt + f"\n\n注意：上一版速報加了原文沒有的提醒（{'、'.join(bad)}），這次不要寫。",
                         {"temperature": 0.2}).text.strip()
        bad = unsupported_advice(text, source)
    how = "AI 摘要"
    if bad:
        print(json.dumps({"severity": "WARNING", "message": "summary_advice", "attempt": 2, "count": len(bad)}))
        text, how = source_front(summary), "原文"
    for s in tsunami_sentences(summary):
        if s not in text:
            text += s
    return text, how



class Severity(str, Enum):
    critical = "critical"
    warning = "warning"
    info = "info"


class AlertAssessment(BaseModel):
    severity: Severity
    affected_areas: list[str]
    action_advice: str
    reason: str


GRADING_RULES = """你是臺灣防災警報分級器。依下表評估示警嚴重度：
地震海嘯：最大震度5弱以上或伴隨海嘯警報=critical；最大震度4級=warning；3級以下=info
氣象：颱風陸上警報、豪雨／大豪雨／超大豪雨特報、大雷雨即時訊息、橙色燈號（高溫、強風等）=critical；大雨特報、黃色燈號=warning；一般天氣提醒=info
水利：淹水一級或二級警戒、土石流紅色警戒=critical；其他淹水警戒、淹水感測、區排警戒、土石流黃色警戒=warning；水庫放流、洩洪通知=info
火災事故：大規模火災、疏散避難=critical；一般火災通報=warning；消防安檢不合格=info
交通：重大鐵路事故=critical；主要幹道封閉=warning；一般封閉=info
民生：大規模停班停課=critical；停水（不論範圍）、森林遊樂區公告、急門診通報=info
其他：海洋污染通報=info

欄位規則：
- affected_areas：地震只列最大震度所在的縣市；其他示警列出原文提到的地區。
- action_advice：只能摘錄示警原文中已有的行動指示，20 字以內；原文沒有行動指示時填空字串，不得自行補充建議。
- reason：寫出依據上表的哪一條。"""

def grade(alert_text: str, cap_severity: str | None) -> tuple[str, str]:
    if official_red(alert_text):
        return "extreme", "官方措辭"
    if cap_severity in CAP_TO_LEVEL:
        return CAP_TO_LEVEL[cap_severity], "官方等級"
    resp = _generate(f"{GRADING_RULES}\n\n評估這則臺灣防災示警的嚴重度：\n{alert_text}",
                     {"response_mime_type": "application/json",
                      "response_schema": AlertAssessment})
    return resp.parsed.severity.value, "AI 判定"



class MultilingualAlert(BaseModel):
    zh: str
    en: str
    ja: str


BASE = """把下面這則臺灣的防災速報寫成三種語言：繁體中文（原文照用）、英文、日文。
規則：
- 時間、地點、數字必須和原文完全一致，不得增加或省略資訊。
- 原文的語氣強弱要保留：「可能」不得寫成「預計」或「將會」。
- 原文是預報（例如「今日有」「可能」）就維持預報語氣，不得寫成正在發生。
- 日文用です・ます体，兩則之間文體要一致。
- 依各語言的習慣表達，不必逐字翻譯。
- 原文若有民國年，一律寫成西元年（民國年＋1911），不加「民國」註記：日文 2026年10月3日、2026年度；英文 October 3, 2026、2026。"""

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
    (("臺灣", "台灣"), "臺灣＝Taiwan／台湾。"),
    (("溪", "河", "川", "江"), "河川名稱（溪、河、川、江）：英文音譯加 River（萬里溪＝Wanli River）；日文照漢字（万里渓）。"),
    (("堰塞湖",), "堰塞湖＝landslide dam lake／堰止湖（不要寫成水庫、水壩湖）。"),
    (("溢流",), "溢流＝overflow／越流。"),
]

GLOSSARY_ITEMS += [((zh, zh.replace("臺", "台")), f"{zh}＝{en}／{ja}（固定寫法，與 App 介面一致）")
                   for code, (en, ja) in COUNTY_I18N.items() for zh in [COUNTY_NAMES[code]]]

EN_RULES = """
英文版的寫法（必須遵守）：
- 原文有具體時刻時，寫成 24 小時制，後面標時區：例如 "11:40 on August 22, 2026 (Taiwan time, UTC+8)"。原文沒有寫出的年、月、時刻一律不補（例如原文只寫「明(26)日」，就寫 "tomorrow (the 26th)"）。
- 震度寫成 "intensity 3 (light shaking) on Taiwan's intensity scale"；描述詞對照：3 light shaking、4 moderate shaking、5 Lower／5 Upper strong shaking、6 Lower／6 Upper violent shaking、7 extreme shaking。
- 只有原文是「特報」時，英文版第一行才先寫一句大寫的白話標題（地震報告等其他速報不加標題），格式「HAZARD: 影響＋時間」，例如 "EXTREMELY HEAVY RAIN: Up to 200 mm of rain possible in 24 hours in the Pingtung County mountains today."，換行後再寫特報的正式內容；特報的產品名稱照中央氣象署英文寫。
- 雨量只寫公釐（mm），溫度只寫攝氏（°C），不要自行換算成英寸或華氏。"""


def glossary_for(text: str) -> str:
    rules = [rule for keys, rule in GLOSSARY_ITEMS if any(k in text for k in keys)]
    return "\n術語與地名規則（必須遵守）：\n" + "\n".join(f"- {r}" for r in rules) if rules else ""


def add_imperial(text: str) -> str:
    return re.sub(r"(\d+(?:\.\d+)?) mm\b",
                  lambda m: f"{m.group(1)} mm (about {float(m.group(1)) / 25.4:.0f} in)", text)


MONTHS = {m: str(i + 1) for i, m in enumerate(
    ["January", "February", "March", "April", "May", "June", "July",
     "August", "September", "October", "November", "December"])}


CN_DIGITS = {"〇": 0, "一": 1, "二": 2, "三": 3, "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9}
FACILITY_NUM_RE = re.compile(r"(?<!\d)(\d+(?!\d)|[一二三四五六七八九十]{1,3})(?!\s*年)"
                             r"\s*(?:號|号|no\.?\s*|#)?\s*\d*\s*(?:號|号)?\s*"
                             r"(?=[一-鿿a-zA-Z.\s]{0,20}?(?:加壓站|Pressuriz|Booster"
                             r"|淨水場|淨水廠|浄水場|Water Treatment|Purification"
                             r"|配水池|Distribution Reservoir|抽水站|Pumping|給水所))", re.I)


def _cn_to_int(cn: str) -> int:
    if "十" not in cn:
        return CN_DIGITS[cn]
    tens, _, ones = cn.partition("十")
    return (CN_DIGITS[tens] if tens else 1) * 10 + (CN_DIGITS[ones] if ones else 0)


def normalize_zh_numbers(text: str) -> str:
    text = to_gregorian(text)
    text = re.sub(r"(第)?([一二三四五六七八九十]{1,3})(?=段|街|線|巷|弄|號|号|期|水庫|ダム|区|丁目|条)",
                  lambda m: str(_cn_to_int(m.group(2))) if all(c in CN_DIGITS or c == "十" for c in m.group(2))
                  else m.group(0), text)
    text = re.sub(r"(下午|晚上|午後|夜)\s*(\d{1,2})(?=\s*[時點時:：])",
                  lambda m: str(int(m.group(2)) + 12) if int(m.group(2)) < 12 else m.group(2), text)
    return FACILITY_NUM_RE.sub(lambda m: m.group(0).replace(m.group(1), "", 1), text)


def numbers(text: str) -> list[str]:
    text = normalize_zh_numbers(text)
    text = re.sub(r"(\d):00(?!\d)", r"\1", text)
    for name, num in MONTHS.items():
        text = re.sub(rf"\b{name}\b", num, text)
    text = re.sub(r"UTC[+-]\d+", "", text)
    return sorted(n.lstrip("0") or "0" if "." not in n else n
                  for n in re.findall(r"\d+(?:\.\d+)?", text))


def check_counties_ja(source: str, ja: str) -> list[str]:
    bad = []
    for name, kind in re.findall(r"([一-鿿]{2})(縣|市)", source):
        if name.replace("台", "臺") + kind not in NAME_TO_CODE:
            continue
        expect = name.replace("臺", "台") + ("県" if kind == "縣" else "市")
        if expect not in ja:
            bad.append(f"{name}{kind}→應為 {expect}")
    return bad


def translate(zh: str) -> tuple[dict, dict]:
    zh = zh.replace("\\", "／")
    src = to_gregorian(zh)
    prompt = BASE + glossary_for(src) + EN_RULES + f"\n\n速報：\n{src}"
    want = numbers(zh)
    passed, report = {}, {}
    for attempt in range(2):
        resp = _generate(prompt, {"response_mime_type": "application/json",
                                  "response_schema": MultilingualAlert})
        out = resp.parsed
        for lang in ("en", "ja"):
            if lang in passed:
                continue
            text = getattr(out, lang).strip()
            problems = [] if numbers(text) == want else ["數字不一致"]
            if roc_in_output(text):
                problems.append("民國年")
            if lang == "ja":
                problems += check_counties_ja(zh, text)
            report[lang] = problems or "通過"
            if problems:
                report[f"{lang}_rejected_{attempt + 1}"] = text
            if not problems:
                passed[lang] = add_imperial(text) if lang == "en" else text
        if len(passed) == 2:
            break
    return passed, report
