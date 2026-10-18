import hashlib
import json
import os
import re
import ssl
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

from pydantic import BaseModel

from . import ai

BASE = "https://opendata.cwa.gov.tw/api/v1/rest/datastore"
DATASETS = {"significant": "E-A0015-001", "local": "E-A0016-001"}
KEEP_DAYS = 30
DUP_SECONDS = 10
DUP_DEGREES = 0.1
TW = timezone(timedelta(hours=8))
LEVELS = ["1級", "2級", "3級", "4級", "5弱", "5強", "6弱", "6強", "7級"]

_CTX = ssl.create_default_context()
_CTX.verify_flags &= ~ssl.VERIFY_X509_STRICT


def cwa_get(dataset: str, **params) -> dict:
    params["Authorization"] = os.environ["CWA_API_KEY"].strip()
    url = f"{BASE}/{dataset}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=30, context=_CTX) as resp:
        return json.load(resp)



DIR_EN = {"北": "N", "北北東": "NNE", "東北": "NE", "東北東": "ENE", "東": "E", "東南東": "ESE",
          "東南": "SE", "南南東": "SSE", "南": "S", "南南西": "SSW", "西南": "SW", "西南西": "WSW",
          "西": "W", "西北西": "WNW", "西北": "NW", "北北西": "NNW"}
DIR_JA = {"東北": "北東", "東南": "南東", "西南": "南西", "西北": "北西"}
LOC_RE = re.compile(r"^(?P<ref>.+?)(?P<dir>[東西南北]{1,3})方\s*(?P<dist>\d*\.?\d+)\s*公里\s*"
                    r"[(（]位於(?P<area>.+?)[)）]$")


def parse_location(loc: str) -> dict | None:
    m = LOC_RE.match(loc)
    if not m or m["dir"] not in DIR_EN:
        return None
    dist = "0" + m["dist"] if m["dist"].startswith(".") else m["dist"]
    return {"ref": m["ref"], "dir": m["dir"], "dist": dist, "distance_km": float(dist), "area": m["area"]}


def compose(p: dict, ref: str, area: str, lang: str) -> str:
    d = p["dist"]
    if lang == "en":
        where = area if area.startswith("off ") else f"in {area}"
        return f"{d} km {DIR_EN[p['dir']]} of {ref} ({where})"
    direction = DIR_JA.get(p["dir"], p["dir"])
    return f"{ref}の{direction} {d} km（{area}）"



def doc_id(eq: dict, report_type: str) -> str:
    if report_type == "significant":
        return str(eq["EarthquakeNo"])
    return "L-" + re.sub(r"[-:]", "", eq["EarthquakeInfo"]["OriginTime"][:19])


def flatten(eq: dict, report_type: str) -> dict:
    info = eq["EarthquakeInfo"]
    areas = [a for a in eq["Intensity"]["ShakingArea"] if a["AreaIntensity"] in LEVELS]
    top = max((a["AreaIntensity"] for a in areas), key=LEVELS.index) if areas else None
    counties = []
    for a in areas:
        if a["AreaIntensity"] == top:
            for name in a["CountyName"].split("、"):
                if name not in counties:
                    counties.append(name)
    loc = re.sub(r"\s+", " ", info["Epicenter"]["Location"]).strip()
    loc = re.sub(r"(?<![\d.])\.(?=\d+\s*公里)", "0.", loc)
    doc = {
        "eq_no": str(eq["EarthquakeNo"]) if report_type == "significant" else None,
        "report_type": report_type,
        "origin_time": info["OriginTime"],
        "magnitude": info["EarthquakeMagnitude"]["MagnitudeValue"],
        "depth_km": info["FocalDepth"],
        "lat": info["Epicenter"]["EpicenterLatitude"],
        "lon": info["Epicenter"]["EpicenterLongitude"],
        "location": loc,
        "max_intensity": top,
        "max_intensity_counties": counties,
        "report_image": eq.get("ReportImageURI"),
        "report_url": eq.get("Web"),
    }
    p = parse_location(loc)
    if p:
        doc.update(distance_km=p["distance_km"], direction_en=DIR_EN[p["dir"]])
    doc["content_hash"] = hashlib.sha1(json.dumps(doc, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    doc["id"] = doc_id(eq, report_type)
    return doc


def drop_duplicates(quakes: list[dict]) -> tuple[list[dict], int]:
    sig = [q for q in quakes if q["report_type"] == "significant"]

    def same(a, b):
        dt = abs(datetime.fromisoformat(a["origin_time"]) - datetime.fromisoformat(b["origin_time"]))
        return (dt.total_seconds() <= DUP_SECONDS and abs(a["lat"] - b["lat"]) <= DUP_DEGREES
                and abs(a["lon"] - b["lon"]) <= DUP_DEGREES)

    kept = [q for q in quakes if q["report_type"] == "significant" or not any(same(q, s) for s in sig)]
    return kept, len(quakes) - len(kept)


def collect(now: datetime | None = None) -> tuple[list[dict], dict]:
    now = now or datetime.now(timezone.utc)
    since = now - timedelta(days=KEEP_DAYS)
    quakes, counts = [], {}
    for rtype, ds in DATASETS.items():
        got = [flatten(eq, rtype) for eq in cwa_get(ds)["records"]["Earthquake"]]
        got = [q for q in got if datetime.fromisoformat(q["origin_time"]) >= since]
        counts[rtype] = len(got)
        quakes += got
    quakes, counts["dropped_duplicate"] = drop_duplicates(quakes)
    return quakes, counts



class PlaceName(BaseModel):
    zh: str
    en: str
    ja: str


class PlaceNames(BaseModel):
    places: list[PlaceName]


PLACE_PROMPT = """把下面這些臺灣的地名翻成英文、日文，用在地震報告的震央位置描述。
規則：
- 只翻地名本身，不加方位、距離或其他說明；每個地名都要回傳，zh 欄照原文。
- 「XX縣政府」「XX市政府」是參考點，照原文的機關名稱翻，不要換成當地的類似機關：
  英文 "Yilan County Government"、"Tainan City Government"；日文「宜蘭県政府」「台南市政府」（不要寫成県庁、市役所）。
- 鄉鎮市區：英文小地名在前、縣市在後，例如 "Nanxi District, Tainan City"；日文由大到小，例如「台南市楠西区」。
- 海域：「臺灣東部海域」寫成 "the sea off eastern Taiwan"／「台湾東部海域」；
  「花蓮縣近海」寫成 "off the coast of Hualien County"／「花蓮県近海」。"""


def check_place(zh: str, lang: str, text: str) -> bool:
    if not text.strip():
        return False
    kinds = [k for _, k in re.findall(r"([一-鿿]{2})(縣|市)", zh)]
    if lang == "ja":
        return not ai.check_counties_ja(zh, text)
    mark = ("County", "City")
    return all((mark[0] if k == "縣" else mark[1]) in text for k in kinds)


def translate_places(names: list[str]) -> dict:
    result = {n: {} for n in names}
    prompt = PLACE_PROMPT + ai.glossary_for("".join(names)) + "\n\n地名：\n" + "\n".join(names)
    for _ in range(2):
        todo = [n for n in names if len(result[n]) < 2]
        if not todo:
            break
        resp = ai._generate(prompt, {"response_mime_type": "application/json", "response_schema": PlaceNames}, kind="place")
        for p in resp.parsed.places:
            if p.zh not in result:
                continue
            for lang in ("en", "ja"):
                text = getattr(p, lang).strip()
                if lang not in result[p.zh] and check_place(p.zh, lang, text):
                    result[p.zh][lang] = text
    return result


def place_translations(db, names: set[str]) -> dict:
    col = db.collection("place_names")
    cache = {}
    for n in names:
        snap = col.document(n).get()
        if snap.exists:
            cache[n] = snap.to_dict()
    missing = sorted(names - cache.keys())
    if missing:
        for n, tr in translate_places(missing).items():
            cache[n] = {**tr, "failed": [l for l in ("en", "ja") if l not in tr]}
            col.document(n).set(cache[n])
    return cache


def add_locations(q: dict, cache: dict) -> None:
    p = parse_location(q["location"])
    if not p:
        return
    ref, area = cache.get(p["ref"], {}), cache.get(p["area"], {})
    for lang in ("en", "ja"):
        if lang in ref and lang in area:
            q[f"location_{lang}"] = compose(p, ref[lang], area[lang], lang)



_seen: dict[str, str] = {}


def sync_quakes(db, quakes: list[dict]) -> dict:
    if quakes and all(_seen.get(q["id"]) == q["content_hash"] for q in quakes):
        return {"written": 0, "places": 0, "no_location": 0, "db_read": False}
    in_db = {s.id: s.to_dict().get("content_hash") for s in db.collection("earthquakes").stream()}
    changed = [q for q in quakes if in_db.get(q["id"]) != q["content_hash"]]
    names = set()
    for q in changed:
        p = parse_location(q["location"])
        if p:
            names |= {p["ref"], p["area"]}
    cache = place_translations(db, names) if names else {}
    now = datetime.now(timezone.utc)
    batch = db.batch()
    for q in changed:
        doc = {k: v for k, v in q.items() if k != "id"}
        add_locations(doc, cache)
        doc["synced_at"] = now
        doc["purge_at"] = datetime.fromisoformat(q["origin_time"]) + timedelta(days=KEEP_DAYS)
        batch.set(db.collection("earthquakes").document(q["id"]), doc)
    if changed:
        batch.commit()
    _seen.clear()
    _seen.update({q["id"]: q["content_hash"] for q in quakes})
    return {"written": len(changed), "places": len(names),
            "no_location": sum(1 for q in changed if not parse_location(q["location"])), "db_read": True}
