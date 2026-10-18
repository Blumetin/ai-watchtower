import contextlib
import io
import json
import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "functions"))
from watchtower import qa

bad = 0


def check(name, got, want):
    global bad
    ok = got == want
    bad += not ok
    print(f"{'OK' if ok else 'NG'}｜{name}｜得到 {got}" + ("" if ok else f"，預期 {want}"))


ROC = "因辦理115年度電氣設備檢驗，115年10月7日9時至17時停水。"

check("中文 term_rules 為空", qa.term_rules("zh"), "")
check("TOOL_SYSTEM 中文與改動前相同",
      qa.TOOL_SYSTEM.format(lang="繁體中文", fence_rule="F", roc_rule=""),
      qa.TOOL_SYSTEM.replace("{roc_rule}", "").format(lang="繁體中文", fence_rule="F"))
check("外語 term_rules 含備援句", qa.ROC_RULE in qa.term_rules("en"), True)

fake_db = SimpleNamespace(collection=lambda c: SimpleNamespace(stream=lambda: [SimpleNamespace(to_dict=lambda: {
    "group": "民生", "raw_category": "停水", "sender": "台灣自來水公司", "updated": "2026-10-06", "summary": ROC,
    "counties": [], "title": ""})]))
qa.set_db(fake_db)
check("工具：中文回答保留民國年", "115年" in qa.get_active_alerts()["alerts"][0]["summary"], True)
tok = qa._TO_AD.set(True)
check("工具：外語回答換成西元", qa.get_active_alerts()["alerts"][0]["summary"].startswith("因辦理2026年度"), True)
qa._TO_AD.reset(tok)

calls = []


def fake_call(fn, kind, model=None, chars=0):
    calls.append(kind)
    return fn()


def make_model(answers):
    it = iter(answers)

    def generate_content(model, contents, config=None):
        calls.append(contents if isinstance(contents, str) else "")
        return SimpleNamespace(text=next(it), automatic_function_calling_history=[])
    return SimpleNamespace(models=SimpleNamespace(generate_content=generate_content))


hit = {"source": "台灣自來水公司", "scenario": "停水", "text": ROC, "url": "https://example.invalid/", "score": 0.9}
saved = qa._call, qa.ai.client, qa.search
qa._call, qa.search = fake_call, (lambda *a, **k: [hit])
log = io.StringIO()
try:
    m = make_model(["Water will be off on October 7, 115.", "Water will be off on October 7, 2026."])
    qa.ai.client = lambda: m
    calls.clear()
    with contextlib.redirect_stdout(log):
        r = qa.answer_with_kb("When is the water off?", "en", emotional=False)
    prompts = [c for c in calls if "問題：" in c]
    check("知識庫：外語提示的資料已換西元", ("2026年度" in prompts[0], "115年" in prompts[0]), (True, False))
    check("知識庫：外語留民國年重試一次", (len(prompts), r["answer"]), (2, "Water will be off on October 7, 2026."))

    m = make_model(["115年10月7日停水。"])
    qa.ai.client = lambda: m
    calls.clear()
    r = qa.answer_with_kb("什麼時候停水", "zh", emotional=False)
    prompts = [c for c in calls if "問題：" in c]
    check("知識庫：中文提示保留民國年、不重試", ("115年" in prompts[0], len(prompts)), (True, 1))

    m = make_model(["On the 115 annual inspection…", "During the 2026 annual inspection…"])
    qa.ai.client = lambda: m
    calls.clear()
    with contextlib.redirect_stdout(log):
        r = qa.answer_with_tools("Any water outages?", "en")
    check("工具：外語留民國年重試一次", (calls.count("ask_tools"), r["answer"]), (2, "During the 2026 annual inspection…"))
    check("工具：呼叫結束後 contextvar 復原", qa._TO_AD.get(), False)
finally:
    qa._call, qa.ai.client, qa.search = saved

lines = [json.loads(l) for l in log.getvalue().splitlines() if l.startswith("{")]
check("roc_in_answer 日誌欄位", sorted({k for l in lines for k in l}), ["attempt", "kind", "lang", "message", "severity"])
check("日誌不含回答內容", any("115" in l or "Water" in l for l in log.getvalue().splitlines()), False)

print(f"\n不符 {bad}")
sys.exit(1 if bad else 0)
