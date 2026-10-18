import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "functions"))
from watchtower import qa
from test_emotion_terms import RULE

GLOSSARY = [
    ("趴下、掩護、穩住", "「まず低く、頭を守り、動かない」（シェイクアウトの安全確保行動）", "Drop, Cover, and Hold On"),
    ("固定、掩護、穩住", "「車いすをロックし、頭を守り、動かない」", "Lock, Cover, and Hold On"),
    ("護住頭頸", "頭と首を守る", "protect your head and neck"),
    ("壓低身體", "姿勢を低くする", "get down low"),
    ("握住桌腳", "机の脚をしっかり持つ", "hold on to the table leg"),
    ("就地掩蔽", "その場で身を守る", "take cover where you are"),
    ("警示燈", "ハザードランプ", "hazard lights"),
    ("避難收容處所", "避難所", "evacuation shelter"),
    ("避難包", "非常用持ち出し袋", "go-bag (emergency kit)"),
    ("疏散", "避難する", "evacuate"),
    ("逃生路線", "避難経路", "evacuation route"),
    ("演練", "訓練", "drills"),
    ("規模", "マグニチュード", "magnitude"),
    ("震度", "震度（台湾の震度階級）", "intensity (on Taiwan's intensity scale)"),
    ("5 弱", "5弱", "5 Lower"),
    ("5 強", "5強", "5 Upper"),
    ("6 弱", "6弱", "6 Lower"),
    ("6 強", "6強", "6 Upper"),
    ("地震速報", "地震速報（揺れの後に発表される地震の情報。日本の緊急地震速報とは別のもの）",
     "earthquake report (issued after the shaking)"),
    ("強震即時警報", "強震即時警報（揺れが届く前に出る警報。日本の緊急地震速報にあたる）", "Earthquake Early Warning"),
    ("地震序列", "一連の地震活動", "earthquake sequence"),
    ("前震", "前震", "foreshock"),
    ("主震", "本震", "mainshock"),
    ("餘震", "余震", "aftershock"),
    ("群震", "群発地震", "earthquake swarm"),
    ("震央", "震央", "epicenter"),
    ("震源", "震源", "hypocenter"),
    ("海嘯警報", "津波警報（台湾の中央気象署の区分）", "Tsunami Warning"),
    ("海嘯警訊", "津波警戒情報（台湾の「海嘯警訊」。3〜6時間以内に到達の見込み）", "Tsunami Watch"),
    ("海嘯消息", "津波に関するお知らせ（台湾の「海嘯消息」。基準未満でも関心が高い場合）", "Tsunami Information"),
    ("海嘯報告", "津波観測報告（台湾の「海嘯報告」。沿岸で実際に観測されたとき）", "Tsunami Report"),
    ("預估波高", "予想される津波の高さ", "estimated wave height"),
    ("颱風警報", "台風警報（台湾の中央気象署が発表）", "typhoon warning"),
    ("土石流", "土石流", "debris flow"),
]
LANG_COL = {"ja": 1, "en": 2}

ZH_ONLY_JA = ["趴下", "掩護", "穩住", "警訊", "疏散", "收容", "演練", "逃生", "警示燈", "餘震", "群震", "颱風", "海嘯",
              "規模5", "規模 ", "預估", "護住"]
CJK = re.compile(r"[一-鿿]")

QUESTIONS = {
    "ja": ["地震のとき家の中ではどうすればいいですか", "車いすの人は地震のときどうすればいいですか",
           "台湾の地震速報とは何ですか", "マグニチュードと震度の違いは何ですか", "台湾の津波の情報にはどんな種類がありますか"],
    "en": ["What should I do indoors during an earthquake?", "What is Taiwan's earthquake report?",
           "What kinds of tsunami alerts does Taiwan issue?"],
}


def glossary_for(context: str, lang: str) -> str:
    rows = [f"- {g[0]} → {g[LANG_COL[lang]]}" for g in GLOSSARY if g[0] in context]
    return "\n用語對照（資料的中文 → 回答用語）：\n" + "\n".join(rows) if rows else ""


HEADER = re.compile(r"[［\[【「\"“][^］\]】」\"”\n]*[｜|][^］\]】」\"”\n]*[］\]】」\"”]")


def leaks(lang: str, q: str, body: str) -> list[str]:
    headers = HEADER.findall(body)
    body = HEADER.sub("", body)
    if lang == "en":
        return CJK.findall(body)
    found = [w for w in ZH_ONLY_JA if w in body]
    if "地震速報" in q and "緊急地震速報" in body and "別" not in body:
        found.append("地震速報→緊急地震速報")
    return found


def run(variant: str, lang: str, q: str) -> str:
    saved = qa.term_rules, qa.glossary_for
    if variant == "A":
        qa.term_rules, qa.glossary_for = (lambda lang: ""), (lambda context, lang: "")
    try:
        return qa.ask(q, lang)["answer"]
    finally:
        qa.term_rules, qa.glossary_for = saved


def main(n: int) -> None:
    out, tally = [], {}
    for lang, qs in QUESTIONS.items():
        for q in qs:
            for variant in ("A", "P"):
                for k in range(n):
                    body = run(variant, lang, q)
                    lk = leaks(lang, q, body)
                    t = tally.setdefault((lang, variant), [0, 0, 0])
                    t[0] += 1
                    t[1] += bool(lk)
                    t[2] += bool(HEADER.search(body))
                    out.append(f"[{lang}][{variant}] {q}｜第 {k + 1} 次｜問題 {sorted(set(lk)) or '無'}")
                    if k == 0:
                        out.append("    " + body.replace("\n", " ⏎ ")[:500])
    out += ["", "== 用語問題（夾帶中文或誤譯，不含段落標頭）／照抄段落標頭／總回答數 =="]
    out += [f"{lang} {v}：{bad}／{hdr}／{total}" for (lang, v), (total, bad, hdr) in sorted(tally.items())]
    text = "\n".join(out)
    print(text)
    (HERE / "logs" / f"disaster_terms_{time.strftime('%Y-%m-%d')}.txt").write_text(text + "\n", encoding="utf-8")


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 3)
