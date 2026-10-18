import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "functions"))

from watchtower import ai, qa

PAIRS = [
    ("zh", "地震時在電梯裡怎麼辦", "地振時在電梯裡怎麼辦", "同音字"),
    ("zh", "颱風來之前要準備什麼", "颱瘋來之前要準備什麼", "同音字"),
    ("zh", "土石流來了要往哪裡跑", "土石留來了要往哪裡跑", "同音字"),
    ("zh", "堰塞湖是什麼", "焉塞湖是什麼", "同音字"),
    ("zh", "餘震會持續多久", "於震會持續多久", "同音字"),
    ("zh", "海嘯警報有哪些種類", "海笑警報有哪些種類", "同音字"),
    ("zh", "避難包要放什麼", "逼難包要放什麼", "同音字"),
    ("zh", "地震後一直睡不著", "地震後一直睡不找", "近音字"),
    ("zh", "地震後很害怕", "地震後很害拍", "近音字"),
    ("zh", "地震後一直很焦慮", "地震後一直很焦綠", "同音字"),
    ("zh", "花蓮特報內容", "花蓮特抱內容", "同音字"),
    ("zh", "明天會不會地震", "明天會不會地振", "同音字"),
    ("zh", "地震的時候要躲哪裡", "地真的時候要躲哪裡", "漏聲調"),
    ("zh", "地震時怎麼辦", "地震时怎么办", "簡體字"),
    ("zh", "錯字要怎麼判斷", "錯字要怎麼半段", "同音字（使用者 9/27 實例）"),
    ("ja", "地震のときどうすればいいですか", "自身のときどうすればいいですか", "変換ミス"),
    ("ja", "地震はありましたか", "自身はありましたか", "変換ミス"),
    ("ja", "避難所はどこですか", "非難所はどこですか", "変換ミス"),
    ("ja", "余震はいつまで続きますか", "予震はいつまで続きますか", "変換ミス"),
    ("ja", "地震予知はできますか", "地震余地はできますか", "変換ミス"),
    ("ja", "警報はありますか", "けいほうはありますか", "未変換"),
    ("ja", "津波のときどこへ逃げればいいですか", "つなみのときどこへ逃げればいいですか", "未変換"),
    ("en", "What should I do during an earthquake?", "What should I do during an earthqauke?", "letter swap"),
    ("en", "Can earthquakes be predicted?", "Can earthqaukes be predicted?", "letter swap"),
    ("en", "Are there any alerts in Taipei?", "Are there any alrets in Taipei?", "letter swap"),
    ("en", "Was there an earthquake?", "Was there an eartquake?", "missing letter"),
    ("en", "How do I prepare for a typhoon?", "How do I prepare for a typhon?", "missing letter"),
    ("en", "What should I do in a tsunami?", "What should I do in a tsunamy?", "wrong letter"),
    ("en", "I'm scared after the earthquake", "I'm scard after the earthquake", "missing letter"),
    ("en", "Where is the nearest evacuation shelter?", "Where is the nearest evacuaton sheltor?", "two typos"),
]

NEGATIVES = [
    ("ja", "自身の安全を確保するにはどうすればいいですか", "自身＝自分自身，不是地震"),
    ("ja", "地震のデマを見て人を非難してもいいですか", "非難＝責備，不是避難"),
    ("ja", "余地のある避難所を探すにはどうすればいいですか", "余地＝空間"),
    ("zh", "921地震是哪一年發生的", "數字與年份"),
    ("zh", "花蓮縣的避難所在哪裡", "地名"),
    ("zh", "欸地震要躲哪", "口語語氣詞"),
    ("zh", "台風跟颱風一樣嗎", "「台風」是在問用字本身"),
    ("zh", "土石流潛勢溪流怎麼查", "專有名詞"),
    ("en", "Is Typhon a Greek god?", "Typhon 是希臘神話人物，離題問題"),
    ("en", "What does the word quake mean?", "quake 本身正確"),
]

CORRECT_PROMPT = """你是防災 App 的輸入校正器。下面是使用者打的一句話，可能有輸入法造成的錯字：同音或近音字、日文漢字變換錯誤或沒有變換的假名、英文拼字錯誤。
規則：
- 只改錯字，不改寫句子、不改語氣、不補字、不翻譯、不換成別的語言。
- 句子本來就通順正確時，原樣輸出。
- 同一個詞在句中本來就說得通時（例如日文「自身の安全」、中文「台風」在問用字），不要改。
- 簡體字改成繁體字。
- 不確定是不是錯字時，不要改。
只輸出 JSON：{{"text": "校正後的句子"}}

句子：
{q}"""


def correct(q: str) -> tuple[str, float]:
    t0 = time.time()
    resp = qa._call(lambda: ai.client().models.generate_content(
        model=qa.GEN_MODEL, contents=CORRECT_PROMPT.format(q=q),
        config={"response_mime_type": "application/json", "temperature": 0}), kind="typo_correct")
    return json.loads(resp.text)["text"].strip(), time.time() - t0


def top(q: str) -> tuple[str, float, float]:
    t0 = time.time()
    h = qa.search(q, emotional=False, top_k=1)[0]
    return h["scenario"], h["score"], time.time() - t0


def main(mode: str) -> None:
    rows, negs = [], []
    for lang, good, bad, kind in PAIRS:
        r = {"lang": lang, "good": good, "bad": bad, "kind": kind,
             "route_good": qa.route(good), "route_bad": qa.route(bad)}
        if mode == "all":
            r["kb_good"], r["score_good"], _ = top(good)
            r["kb_bad"], r["score_bad"], _ = top(bad)
            r["fixed"], r["t_fix"] = correct(bad)
            r["route_fixed"] = qa.route(r["fixed"])
            r["kb_fixed"], r["score_fixed"], _ = top(r["fixed"])
            r["unchanged_good"] = correct(good)[0] == good
        rows.append(r)
        print(json.dumps(r, ensure_ascii=False))
    if mode == "all":
        for lang, q, note in NEGATIVES:
            out, t = correct(q)
            negs.append({"lang": lang, "q": q, "out": out, "kept": out == q, "note": note, "t": round(t, 2)})
            print(json.dumps(negs[-1], ensure_ascii=False))
    json.dump({"pairs": rows, "negatives": negs},
              open(os.path.join(HERE, "logs", f"typo_correct_eval_{time.strftime('%Y-%m-%d')}_{mode}.json"), "w",
                   encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "all")
