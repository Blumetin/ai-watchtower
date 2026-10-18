
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "content"

LANG_HEADINGS = {"## 一、中文": "zh", "## 二、English": "en", "## 三、日本語": "ja"}
SECTION_IDS = ["bag", "response", "first_aid"]
BLOCK_IDS = {
    "bag": ["bag"],
    "response": ["earthquake", "typhoon", "tsunami", "debris_flow", "fire"],
    "first_aid": ["burns", "bleeding", "collapse"],
}
SOURCE_PREFIX = re.compile(r"^(資料來源：|Sources?: |出典：)")

LINKS = {
    "bag": [
        "https://prepare.mnd.gov.tw/emergency-supplies/go-bag",
        "https://www.nfa.gov.tw/cht/index.php?code=list&flag=detail&ids=1468&article_id=18936",
    ],
    "earthquake": [
        "https://www.tfdp.com.tw/cht/index.php?code=list&flag=detail&ids=52&article_id=123",
        "https://prepare.mnd.gov.tw/emergency-responses",
    ],
    "typhoon": ["https://prepare.mnd.gov.tw/emergency-responses"],
    "tsunami": [
        "https://scweb.cwa.gov.tw/zh-tw/guidance/protection/226",
        "https://prepare.mnd.gov.tw/emergency-responses",
    ],
    "debris_flow": ["https://prepare.mnd.gov.tw/emergency-responses"],
    "fire": ["https://www.tfdp.com.tw/cht/index.php?code=list&flag=detail&ids=55&article_id=152"],
    "burns": [
        "https://www.mohw.gov.tw/cp-16-80496-1.html",
        "https://www.disasterlearning.gov.taipei/tw/Knowledge/ugC_Knowledge_Detail.aspx?ID=120&TID=6",
        "https://prepare.mnd.gov.tw/casualty-care-procedures",
    ],
    "bleeding": ["https://prepare.mnd.gov.tw/casualty-care-procedures"],
    "collapse": ["https://prepare.mnd.gov.tw/casualty-care-procedures"],
}


def parse(md: str) -> dict:
    langs, lang, sections, section, block, group = {}, None, None, None, None, None

    def new_block():
        return {"groups": [], "source": "", "links": []}

    for raw in md.splitlines():
        line = raw.rstrip()
        head = next((h for h in LANG_HEADINGS if line.startswith(h)), None)
        if head:
            lang = LANG_HEADINGS[head]
            sections = langs.setdefault(lang, [])
            section = None
            continue
        if line.startswith("## "):
            lang = None
            continue
        if lang is None or not line or line == "---":
            continue
        if line.startswith("### "):
            title = re.sub(r"[（(].*[）)]$", "", line[4:]).strip()
            section = {"id": SECTION_IDS[len(sections)], "title": title, "blocks": []}
            sections.append(section)
            block, group = new_block(), None
            continue
        if section is None:
            continue
        m = re.match(r"^\*\*(.+?)\*\*\s*(.*)$", line)
        if m:
            note = m.group(2).strip()
            note = note[1:-1] if note[:1] in "（(" and note[-1:] in "）)" else note
            group = {"title": m.group(1), "note": note, "items": [], "numbered": False, "pending": []}
            block["groups"].append(group)
            continue
        if SOURCE_PREFIX.match(line):
            block["source"] = line
            bid = BLOCK_IDS[section["id"]][len(section["blocks"])]
            block["id"] = bid
            block["links"] = LINKS.get(bid, [])
            section["blocks"].append(block)
            block, group = new_block(), None
            continue
        m = re.match(r"^(?:- |\d+\. )(.+)$", line)
        if m and group is not None:
            group["numbered"] = group["numbered"] or bool(re.match(r"^\d+\. ", line))
            group["items"].append(m.group(1))
            continue
        if line[:1] in "（(" and group is not None:
            group["pending"].append(line)
    return langs


def main() -> None:
    langs = parse(Path(sys.argv[1]).read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    for lang, sections in langs.items():
        by_id = {s["id"]: s for s in sections}
        assert set(by_id) == set(SECTION_IDS), (lang, list(by_id))
        for s in sections:
            assert [b["id"] for b in s["blocks"]] == BLOCK_IDS[s["id"]], (lang, s["id"])
        main_part = {"sections": [by_id["bag"], by_id["response"]]}
        (OUT / f"prep_{lang}.json").write_text(json.dumps(main_part, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        (OUT / f"first_aid_{lang}.json").write_text(
            json.dumps({"section": by_id["first_aid"]}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
        )
        checklist = by_id["bag"]["blocks"][0]["groups"][1]["items"]
        print(lang, "checklist items:", len(checklist), "response blocks:", len(by_id["response"]["blocks"]))
    counts = {
        tuple(len(g["items"]) for g in json.loads((OUT / f"prep_{l}.json").read_text())["sections"][0]["blocks"][0]["groups"][1:3])
        for l in langs
    }
    assert len(counts) == 1, counts


if __name__ == "__main__":
    main()
