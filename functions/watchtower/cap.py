import re
import urllib.error
import urllib.request
from urllib.parse import urlparse
import xml.etree.ElementTree as ET

SEVERITY_ORDER = ["Minor", "Moderate", "Severe", "Extreme"]
CAP_TO_LEVEL = {"Extreme": "extreme", "Severe": "critical",
                "Moderate": "warning", "Minor": "info"}

RED_RE = re.compile(r"紅色(?:警戒|燈號|警報|警示)|(?:警戒|燈號)(?:為|達|發布)?紅色")
RED_CANCEL_RE = re.compile(r"解除|調降|降為|降級|取消")


def official_red(text: str) -> bool:
    for m in RED_RE.finditer(text.replace("台", "臺")):
        start = max(text.rfind(p, 0, m.start()) for p in "。；！？\n") + 1
        ends = [i for i in (text.find(p, m.end()) for p in "。；！？\n") if i >= 0]
        if not RED_CANCEL_RE.search(text[start:min(ends) if ends else len(text)]):
            return True
    return False

COUNTY_CODES = {
    "63": "tpe", "64": "khh", "65": "nwt", "66": "txg", "67": "tnn", "68": "tao",
    "10002": "ila", "10004": "hsq", "10005": "mia", "10007": "cha", "10008": "nan",
    "10009": "yun", "10010": "cyq", "10013": "pif", "10014": "ttt", "10015": "hua",
    "10016": "pen", "10017": "kee", "10018": "hsz", "10020": "cyi",
    "09007": "lie", "09020": "kin",
}
COUNTY_NAMES = {
    "tpe": "臺北市", "khh": "高雄市", "nwt": "新北市", "txg": "臺中市", "tnn": "臺南市",
    "tao": "桃園市", "ila": "宜蘭縣", "hsq": "新竹縣", "mia": "苗栗縣", "cha": "彰化縣",
    "nan": "南投縣", "yun": "雲林縣", "cyq": "嘉義縣", "pif": "屏東縣", "ttt": "臺東縣",
    "hua": "花蓮縣", "pen": "澎湖縣", "kee": "基隆市", "hsz": "新竹市", "cyi": "嘉義市",
    "lie": "連江縣", "kin": "金門縣",
}
NAME_TO_CODE = {name: code for code, name in COUNTY_NAMES.items()}
COUNTY_I18N = {
    "kee": ("Keelung City", "基隆市"), "tpe": ("Taipei City", "台北市"),
    "nwt": ("New Taipei City", "新北市"), "tao": ("Taoyuan City", "桃園市"),
    "hsz": ("Hsinchu City", "新竹市"), "hsq": ("Hsinchu County", "新竹県"),
    "mia": ("Miaoli County", "苗栗県"), "txg": ("Taichung City", "台中市"),
    "cha": ("Changhua County", "彰化県"), "nan": ("Nantou County", "南投県"),
    "yun": ("Yunlin County", "雲林県"), "cyi": ("Chiayi City", "嘉義市"),
    "cyq": ("Chiayi County", "嘉義県"), "tnn": ("Tainan City", "台南市"),
    "khh": ("Kaohsiung City", "高雄市"), "pif": ("Pingtung County", "屏東県"),
    "ila": ("Yilan County", "宜蘭県"), "hua": ("Hualien County", "花蓮県"),
    "ttt": ("Taitung County", "台東県"), "pen": ("Penghu County", "澎湖県"),
    "kin": ("Kinmen County", "金門県"), "lie": ("Lienchiang County", "連江県"),
}
EN_NAMES = {
    "taipei": "tpe", "kaohsiung": "khh", "new taipei": "nwt", "taichung": "txg", "tainan": "tnn",
    "taoyuan": "tao", "yilan": "ila", "hsinchu county": "hsq", "miaoli": "mia", "changhua": "cha",
    "nantou": "nan", "yunlin": "yun", "chiayi county": "cyq", "pingtung": "pif", "taitung": "ttt",
    "hualien": "hua", "penghu": "pen", "keelung": "kee", "hsinchu city": "hsz", "chiayi city": "cyi",
    "lienchiang": "lie", "matsu": "lie", "kinmen": "kin",
}


def county_code(name: str) -> str | None:
    name = name.strip().replace("台", "臺")
    if name in NAME_TO_CODE:
        return NAME_TO_CODE[name]
    for zh, code in NAME_TO_CODE.items():
        if len(name) >= 2 and zh.startswith(name) and name not in ("新竹", "嘉義"):
            return code
    key = name.lower().replace(" city", "").replace(" county", "") \
        if not name.lower().startswith(("hsinchu", "chiayi")) else name.lower()
    return EN_NAMES.get(key)


def county_from_geocode(value: str) -> str | None:
    value = value.strip()
    if value[:2] in COUNTY_CODES and value[:2] != "10" and not value.startswith("09"):
        return COUNTY_CODES[value[:2]]
    return COUNTY_CODES.get(value[:5])


SHORT_NAMES = {"宜蘭": "ila", "花蓮": "hua", "臺東": "ttt", "屏東": "pif", "高雄": "khh", "臺南": "tnn",
               "雲林": "yun", "南投": "nan", "彰化": "cha", "臺中": "txg", "苗栗": "mia", "桃園": "tao",
               "基隆": "kee", "澎湖": "pen", "金門": "kin", "連江": "lie", "馬祖": "lie", "臺北": "tpe", "新北": "nwt"}


def counties_from_text(text: str) -> list[str]:
    text = text.replace("台", "臺")
    full = [code for name, code in NAME_TO_CODE.items() if name in text]
    if full:
        return full
    short = []
    for name, code in SHORT_NAMES.items():
        if name in text and code not in short:
            short.append(code)
    if "nwt" in short and "tpe" in short:
        short.remove("tpe")
    return short


def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _norm(text: str | None) -> str:
    return re.sub(r"\s+", "", text or "")


def _combine(infos: list[dict]) -> dict:
    counties, county_sev = [], {}
    for info in infos:
        sev = info["severity"]
        for code in info["counties"]:
            if code not in counties:
                counties.append(code)
            if sev and (code not in county_sev or SEVERITY_ORDER.index(sev) > SEVERITY_ORDER.index(county_sev[code])):
                county_sev[code] = sev
    sevs = [i["severity"] for i in infos if i["severity"]]
    return {"cap_severity": max(sevs, key=SEVERITY_ORDER.index) if sevs else None, "counties": counties,
            "county_levels": {c: CAP_TO_LEVEL[v] for c, v in county_sev.items()}}


def _same(description: str, summary: str) -> bool:
    if not description or not summary:
        return False
    short, long_ = sorted((description, summary), key=len)
    return description == summary or (len(short) >= 10 and short in long_)


def for_alert(cap: dict, title: str, summary: str) -> dict:
    infos = cap["infos"]
    if len({i["description"] for i in infos}) <= 1:
        return {**_combine(infos), "county_source": "cap"}
    s = _norm(summary)
    picked = [i for i in infos if _same(i["description"], s)]
    if picked:
        return {**_combine(picked), "county_source": "cap_info"}
    text = counties_from_text(title + summary)
    if text:
        whole = _combine(infos)
        return {"cap_severity": whole["cap_severity"], "counties": text,
                "county_levels": {c: v for c, v in whole["county_levels"].items() if c in text},
                "county_source": "text"}
    return {**_combine(infos), "county_source": "cap_all"}


def instruction_for(cap: dict, summary: str) -> str:
    infos = cap.get("infos") or []
    if len({i["description"] for i in infos}) > 1:
        s = _norm(summary)
        infos = [i for i in infos if _same(i["description"], s)]
    return "\n".join(dict.fromkeys(i.get("instruction", "") for i in infos if i.get("instruction")))


def parse_cap(xml_text: str) -> dict:
    root = ET.fromstring(xml_text)
    top = {_local(el.tag): (el.text or "").strip() for el in root}
    infos = []
    for info in [el for el in root.iter() if _local(el.tag) == "info"] or [root]:
        sev, info_counties, info_text, desc, headline, instr = None, [], [], "", "", ""
        for el in info.iter():
            tag = _local(el.tag)
            if tag == "severity" and el.text in SEVERITY_ORDER:
                sev = el.text
            elif tag == "description":
                desc = _norm(el.text)
            elif tag == "headline":
                headline = (el.text or "").strip()
            elif tag == "instruction":
                instr = _norm(el.text)
            elif tag == "areaDesc" and el.text:
                info_text.append(el.text)
            elif tag == "geocode":
                name = value = ""
                for child in el:
                    if _local(child.tag) == "valueName":
                        name = child.text or ""
                    elif _local(child.tag) == "value":
                        value = child.text or ""
                if name.startswith("Taiwan_Geocode") and value:
                    code = county_from_geocode(value)
                    if code and code not in info_counties:
                        info_counties.append(code)
        if not info_counties:
            info_counties = counties_from_text(" ".join(info_text))
        infos.append({"severity": sev, "counties": info_counties, "description": desc,
                      "headline": headline, "area_desc": " ".join(info_text), "instruction": instr})
    refs = [r.split(",")[1] for r in top.get("references", "").split() if r.count(",") >= 2]
    return {**_combine(infos), "infos": infos,
            "cap_status": top.get("status") or None, "cap_msg_type": top.get("msgType") or None,
            "cap_identifier": top.get("identifier") or None, "cap_references": refs}


CAP_HOSTS = ("alerts.ncdr.nat.gov.tw", ".ncdr.nat.gov.tw", ".cwa.gov.tw")


def allowed_cap_url(url: str) -> bool:
    p = urlparse(url)
    host = (p.hostname or "").lower()
    return p.scheme == "https" and any(host == h or host.endswith(h) for h in CAP_HOSTS)


class _NoRedirect(urllib.request.HTTPRedirectHandler):

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise urllib.error.HTTPError(req.full_url, code, f"redirect blocked: {newurl}", headers, fp)


_opener = urllib.request.build_opener(_NoRedirect)


def fetch_cap(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": "disaster-assistant/0.1"})
    from .fetch_ncdr import open_with_retry
    with open_with_retry(req, timeout=20, opener=_opener, waits=(25,), budget=60) as resp:
        return parse_cap(resp.read().decode("utf-8", "replace"))
