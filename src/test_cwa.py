import json
import os
import ssl
import urllib.parse
import urllib.request

BASE = "https://opendata.cwa.gov.tw/api/v1/rest/datastore"

_CTX = ssl.create_default_context()
_CTX.verify_flags &= ~ssl.VERIFY_X509_STRICT


def cwa_get(dataset: str, **params) -> dict:
    params["Authorization"] = os.environ["CWA_API_KEY"].strip()
    url = f"{BASE}/{dataset}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=30, context=_CTX) as resp:
        return json.load(resp)


LEVELS = ["1級", "2級", "3級", "4級", "5弱", "5強", "6弱", "6強", "7級"]


def flatten(eq: dict) -> dict:
    info = eq["EarthquakeInfo"]
    areas = [a for a in eq["Intensity"]["ShakingArea"]
             if a["AreaIntensity"] in LEVELS]
    top = max((a["AreaIntensity"] for a in areas), key=LEVELS.index)
    counties = []
    for a in areas:
        if a["AreaIntensity"] == top:
            for name in a["CountyName"].split("、"):
                if name not in counties:
                    counties.append(name)
    return {
        "origin_time": info["OriginTime"],
        "location": info["Epicenter"]["Location"],
        "magnitude": info["EarthquakeMagnitude"]["MagnitudeValue"],
        "depth_km": info["FocalDepth"],
        "max_intensity": top,
        "max_intensity_counties": counties,
    }


if __name__ == "__main__":
    quakes = cwa_get("E-A0015-001", limit=5)
    print("== E-A0015-001 顯著有感地震（最近 5 筆）==")
    for eq in quakes["records"]["Earthquake"]:
        info = eq["EarthquakeInfo"]
        print(info["OriginTime"],
              f"規模 {info['EarthquakeMagnitude']['MagnitudeValue']}",
              f"深度 {info['FocalDepth']} km",
              info["Epicenter"]["Location"])

    print("\n== 8/22 東部海域地震（timeFrom 查詢）==")
    aug = cwa_get("E-A0015-001", timeFrom="2026-08-22T00:00:00", timeTo="2026-08-23T00:00:00")
    for eq in aug["records"]["Earthquake"]:
        info = eq["EarthquakeInfo"]
        print(info["OriginTime"],
              f"規模 {info['EarthquakeMagnitude']['MagnitudeValue']}",
              f"深度 {info['FocalDepth']} km",
              info["Epicenter"]["Location"])
        print("  ReportContent:", eq.get("ReportContent", "")[:120])
        print("  整理成單層字典:", json.dumps(flatten(eq), ensure_ascii=False))

    print("\n== W-C0033-001 天氣特報（現況）==")
    warn = cwa_get("W-C0033-001", limit=100)
    locs = warn["records"]["location"]
    active = [(l["locationName"], h["phenomena"], h["significance"])
              for l in locs
              for h in l["hazardConditions"].get("hazards", [])
              for h in [h["info"]]] if locs else []
    print(f"縣市數 {len(locs)}；有特報的縣市：")
    if not active:
        print("（目前無生效中特報）")
    for a in active[:10]:
        print(" ", a)
