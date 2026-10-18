import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "functions"))
from watchtower import qa

CASES = [
    ("ja", "・呼吸法（呼吸練習）を行う", "・呼吸法を行う"),
    ("ja", "筋弛緩法（肌肉放鬆）、瞑想", "筋弛緩法、瞑想"),
    ("ja", "避難所 (避難收容處所) へ行く", "避難所へ行く"),
    ("en", "Try breathing exercises (呼吸練習) and meditation.", "Try breathing exercises and meditation."),
    ("en", "Use Drop, Cover, and Hold On (趴下、掩護、穩住).", "Use Drop, Cover, and Hold On."),
    ("ja", "台南市（台南市）の避難所", "台南市（台南市）の避難所"),
    ("ja", "中央気象署（中央気象署）が発表", "中央気象署（中央気象署）が発表"),
    ("ja", "心療内科（精神科）を受診", "心療内科（精神科）を受診"),
    ("ja", "震度（台湾の震度階級）5弱", "震度（台湾の震度階級）5弱"),
    ("ja", "マグニチュード（M）7.0", "マグニチュード（M）7.0"),
    ("en", "the Central Weather Administration (中央氣象署)", "the Central Weather Administration (中央氣象署)"),
    ("zh", "呼吸法（呼吸練習）", "呼吸法（呼吸練習）"),
]


def main() -> int:
    bad = 0
    for lang, src, want in CASES:
        got = qa.strip_zh_parens(src, lang)
        ok = got == want
        bad += not ok
        print(f"{'OK' if ok else 'NG'}｜[{lang}] {src} → {got}" + ("" if ok else f"（預期 {want}）"))
    print(f"\n不符 {bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
