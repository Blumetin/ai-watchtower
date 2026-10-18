import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "functions"))
from watchtower import ai, rocdate

bad = 0


def check(name, got, want):
    global bad
    ok = got == want
    bad += not ok
    print(f"{'OK' if ok else 'NG'}｜{name}｜得到 {got!r}" + ("" if ok else f"，預期 {want!r}"))


g = rocdate.to_gregorian
check("115年10月03日", g("時間自115年10月03日17時21分"), "時間自2026年10月03日17時21分")
check("115年10月3日", g("115年10月3日"), "2026年10月3日")
check("115/10/03", g("公告日期 115/10/03"), "公告日期 2026/10/03")
check("115.10.03", g("115.10.03 起"), "2026.10.03 起")
check("民國115年", g("民國115年颱風"), "2026年颱風")
check("中華民國115年10月3日", g("中華民國115年10月3日"), "2026年10月3日")
check("115年度", g("115年度防汛"), "2026年度防汛")
check("民國99年（兩位數，有民國）", g("民國99年"), "2010年")
check("跨年區間", g("115年12月31日至116年1月2日"), "2026年12月31日至2027年1月2日")
check("跨年斜線", g("115/12/31-116/01/02"), "2026/12/31-2027/01/02")
check("區間年度", g("為辦理本廠115-116年度管網改善"), "為辦理本廠2026-2027年度管網改善")
check("區間至", g("115至116年度"), "2026至2027年度")
check("區間年月", g("115～116年1月"), "2026～2027年1月")
check("只有月日", g("10月3日17時至18時"), "10月3日17時至18時")
check("只有斜線月日", g("10/03 17:00"), "10/03 17:00")
check("西元年月日", g("2026年10月3日"), "2026年10月3日")
check("西元斜線", g("2026/10/03"), "2026/10/03")
for t in ("百年一遇", "200年重現期", "近10年", "50年", "100年來最大", "115年後"):
    check(f"不換：{t}", g(t), t)
o = rocdate.roc_in_output
check("輸出含民國", o("民國115年10月3日"), True)
check("輸出 115年10月", o("115年10月03日から"), True)
check("輸出 115/10/03", o("on 115/10/03"), True)
check("輸出英文加註 ROC 曆", o("the 115-116 (Republic of China calendar) project"), True)
check("輸出日文年度", o("115年度の工事"), True)
check("輸出英文月日接民國年", o("17:21 to 18:21 on October 03, 115 (Taiwan time)"), True)
check("輸出英文 115 annual", o("the 115 annual electrical inspection"), True)
check("輸出英文 115th year", o("Due to the 115th year electrical equipment inspection"), True)
check("輸出英文序數不誤判", o("the 21st floor"), False)
check("輸出英文西元月日年", o("October 3, 2026"), False)
check("輸出西元年度", o("2026年度の工事"), False)
check("輸出一般數字 115 不誤判", o("115 households affected"), False)
check("不誤判：中華民国", o("中華民国（台湾）の中央気象署"), False)
check("不誤判：ROC Armed Forces", o("the ROC Armed Forces will assist"), False)
check("輸出 民国115", o("民国115年"), True)
check("輸出 ROC calendar", o("in the ROC calendar"), True)
check("輸出 ROC 115", o("ROC 115"), True)
check("輸出西元日文", o("2026年10月3日"), False)
check("輸出西元英文", o("October 3, 2026"), False)
n = lambda t: ai.numbers(g(t))
check("數字核對：原文民國、譯文西元", n("115年10月03日17時21分") == n("October 3, 2026, 17:21"), True)
check("數字核對：跨年", n("115年12月31日至116年1月2日") == n("2026年12月31日から2027年1月2日まで"), True)
check("numbers 內建換算", ai.numbers("115年10月03日") == ai.numbers("October 3, 2026"), True)
check("年度＋加壓站（英）", ai.numbers("因辦理115年度電氣設備檢驗，加壓站暫停供水。")
      == ai.numbers("Water supply from the booster station is suspended for 2026 electrical equipment inspections."), True)
check("設施編號照舊", ai.numbers("忠義二加壓站停水") == ai.numbers("Water outage at Zhongyi No. 2 Booster Station"), True)
print(f"\n不符 {bad}")
sys.exit(1 if bad else 0)
