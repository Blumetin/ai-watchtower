from dataclasses import dataclass, asdict
from datetime import datetime, timedelta, timezone
from hashlib import sha1

CATEGORY_MAP = {
    "颱風": "氣象", "高溫": "氣象", "降雨": "氣象", "雷雨": "氣象", "強風": "氣象",
    "地震": "地震海嘯", "海嘯": "地震海嘯",
    "水庫放流": "水利", "淹水": "水利", "淹水感測": "水利", "區排警戒": "水利",
    "河川高水位": "水利", "交流道下地方連絡道淹水": "水利",
    "土石流及大規模崩塌": "水利",
    "火災": "火災事故", "消防安全檢查重大不合格場所": "火災事故",
    "海洋污染": "其他",
    "鐵路事故": "交通", "道路封閉": "交通", "高速公路路況事件": "交通",
    "停水": "民生", "行動電話中斷": "民生", "停班停課": "民生",
    "疏散避難": "民生", "國家森林遊樂區": "民生",
    "空氣品質": "氣象",
}

TEST_CATEGORIES = {"ncdrSystemTest"}


@dataclass
class Alert:
    uid: str
    raw_id: str
    group: str
    raw_category: str
    title: str
    summary: str
    sender: str
    updated: datetime
    status: str
    expires: datetime | None = None
    cap_link: str = ""

    def to_dict(self) -> dict:
        d = asdict(self)
        d["updated"] = self.updated.isoformat()
        d["expires"] = self.expires.isoformat() if self.expires else None
        return d


TW = timezone(timedelta(hours=8))


def parse_expires(text: str) -> datetime | None:
    try:
        date, ampm, clock = text.split()
        y, m, d = (int(x) for x in date.split("/"))
        hh, mm, ss = (int(x) for x in clock.split(":"))
        if ampm == "下午" and hh < 12:
            hh += 12
        if ampm == "上午" and hh == 12:
            hh = 0
        return datetime(y, m, d, hh, mm, ss, tzinfo=TW)
    except (ValueError, AttributeError):
        return None


def clean_summary(text: str) -> str:
    return text.replace("\\", "／")


def normalize(raw: dict) -> Alert:
    summary = raw.get("summary") or ""
    expires = parse_expires(raw.get("expires", ""))
    if "已結案" in summary:
        status = "closed"
    elif expires and expires < datetime.now(TW):
        status = "expired"
    else:
        status = "active"
    digest = sha1(f"{raw['id']}|{raw['updated']}|{summary}".encode()).hexdigest()[:8]
    return Alert(
        uid=f"{raw['id']}#{digest}",
        raw_id=raw["id"],
        group=CATEGORY_MAP.get(raw["category"], "其他"),
        raw_category=raw["category"],
        title=raw["title"],
        summary=clean_summary(summary),
        sender=raw["sender"],
        updated=datetime.fromisoformat(raw["updated"]),
        status=status,
        expires=expires,
        cap_link=raw.get("cap_link", ""),
    )


def dedupe(alerts: list[Alert]) -> list[Alert]:
    latest: dict[str, Alert] = {}
    for a in alerts:
        if a.uid not in latest or a.updated > latest[a.uid].updated:
            latest[a.uid] = a
    return sorted(latest.values(), key=lambda a: a.updated, reverse=True)


def pipeline(raw_alerts: list[dict]) -> list[Alert]:
    return dedupe([normalize(r) for r in raw_alerts
                   if r.get("category") not in TEST_CATEGORIES])


if __name__ == "__main__":
    import json, sys
    from collections import Counter
    raw = json.load(open(sys.argv[1]))
    out = pipeline(raw)
    active = [a for a in out if a.status == "active"]
    print(f"原始 {len(raw)} 筆 → 去除完全重複後 {len(out)} 筆 → "
          f"狀態 {dict(Counter(a.status for a in out))} → 生效中 {len(active)} 筆")
    print("六大類分布：", dict(Counter(a.group for a in active).most_common()))
    unmapped = sorted({a.raw_category for a in out if a.group == "其他"})
    if unmapped:
        print("⚠️ 未對照分類：", unmapped)
