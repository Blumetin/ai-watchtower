import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "functions"))
from watchtower import qa

GLOSSARY = [
    ("呼吸練習", "呼吸法", "breathing exercises"),
    ("肌肉放鬆", "筋弛緩法（漸進的筋弛緩法）", "progressive muscle relaxation"),
    ("冥想", "瞑想", "meditation"),
    ("放鬆技巧", "リラクセーション法", "relaxation techniques"),
    ("支持團體", "サポートグループ（自助グループ）", "support groups"),
    ("寫日記", "日記をつける", "keeping a journal"),
    ("尋求諮商", "カウンセリングを受ける", "seeing a counselor"),
    ("維持正常作息", "生活リズムを保つ", "keeping a regular routine"),
    ("菸酒過量", "飲酒や喫煙が増える", "drinking or smoking too much"),
    ("迴避社交", "人づきあいを避ける", "avoiding other people"),
    ("過度投入工作", "仕事に没頭しすぎる", "overworking"),
    ("精神科", "精神科", "psychiatrist"),
    ("身心科", "心療内科", "psychosomatic medicine clinic"),
    ("臨床心理師", "臨床心理士・公認心理師", "clinical psychologist"),
    ("諮商心理師", "カウンセラー（心理職）", "counseling psychologist"),
    ("社區心理衛生中心", "地域の精神保健センター", "community mental health center"),
    ("急性壓力症", "急性ストレス障害（ASD）", "acute stress disorder (ASD)"),
    ("創傷後壓力症", "心的外傷後ストレス障害（PTSD）", "post-traumatic stress disorder (PTSD)"),
    ("過度警覺", "過覚醒", "hypervigilance"),
    ("逃避會想起災難的場景", "災害を思い出す場所や状況を避ける", "avoiding places or situations that bring back the disaster"),
    ("困擾的災難回憶或畫面", "つらい記憶や場面が繰り返しよみがえる", "distressing memories or images of the disaster"),
    ("低落憂鬱", "気分の落ち込み", "low mood or depression"),
    ("麻木", "感情が麻痺したような感じ", "feeling numb"),
    ("疏離", "周囲から切り離された感じ", "feeling detached from others"),
    ("效能感", "自分にもできるという感覚", "a sense of being able to cope"),
    ("安靜能繫望", "台湾衛生福利部の「安・静・能・繫・望」の5つのヒント", 'the "five tips" from Taiwan\'s Ministry of Health and Welfare'),
]
LANG_COL = {"ja": 1, "en": 2}

RULE = ("- 用{lang}回答時，資料是中文：資料裡的名稱與專有用語，一律換成{lang}一般人熟悉的通用說法，不要照抄中文用詞，"
        "也不要在{lang}裡夾中文，不要先寫中文原句再用括號翻譯；有「用語對照」時照對照寫。")

ZH_ONLY_JA = ["肌肉", "放鬆", "諮商", "身心科", "社區", "心理衛生", "壓力症", "創傷後", "警覺", "團體", "菸酒", "作息",
              "安靜能繫望", "效能感", "諮商心理師", "臨床心理師", "憂鬱", "迴避", "逃避", "練習放鬆", "呼吸練習"]
CJK = re.compile(r"[一-鿿]")

QUESTIONS = {
    "ja": ["地震の後、眠れません", "余震が怖くて落ち着きません", "最近、悪夢ばかり見ます", "地震のあと不安で涙が出ます"],
    "en": ["I can't sleep since the earthquake", "I'm scared of the aftershocks", "I keep having nightmares after the quake"],
}


def glossary_for(context: str, lang: str) -> str:
    rows = [f"- {zh} → {g[LANG_COL[lang]]}" for zh, *rest in GLOSSARY for g in [(zh, *rest)] if zh in context]
    return "\n用語對照（資料的中文 → 回答用語）：\n" + "\n".join(rows) if rows else ""


def leaks(lang: str, body: str) -> list[str]:
    if lang == "en":
        return CJK.findall(body)
    return [w for w in ZH_ONLY_JA if w in body]


def run(variant: str, lang: str, q: str) -> str:
    saved = qa.term_rules, qa.glossary_for
    if variant == "A":
        qa.term_rules, qa.glossary_for = (lambda lang: ""), (lambda context, lang: "")
    try:
        return qa.answer_with_kb(q, lang, emotional=True)["answer"]
    finally:
        qa.term_rules, qa.glossary_for = saved


def main(n: int) -> None:
    out, tally = [], {}
    for lang, qs in QUESTIONS.items():
        for q in qs:
            for variant in ("A", "P"):
                for k in range(n):
                    body = run(variant, lang, q)
                    lk = leaks(lang, body)
                    t = tally.setdefault((lang, variant), [0, 0])
                    t[0] += 1
                    t[1] += bool(lk)
                    out.append(f"[{lang}][{variant}] {q}｜第 {k + 1} 次｜夾帶 {sorted(set(lk)) or '無'}")
                    if k == 0:
                        out.append("    " + body.replace("\n", " ⏎ ")[:400])
    out.append("")
    out.append("== 夾帶中文用詞的回答數／總回答數 ==")
    for (lang, v), (total, bad) in sorted(tally.items()):
        out.append(f"{lang} {v}：{bad}／{total}")
    text = "\n".join(out)
    print(text)
    (HERE / "logs" / f"emotion_terms_{time.strftime('%Y-%m-%d')}.txt").write_text(text + "\n", encoding="utf-8")


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 5)
