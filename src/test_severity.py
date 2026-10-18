import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "functions"))

from watchtower import ai
from watchtower.cap import CAP_TO_LEVEL, official_red, parse_cap

fails = 0


def check(label, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(f"  {'OK' if ok else 'NG'}  {label}：{got}" + ("" if ok else f"（應為 {want}）"))


print("== CAP 對照表（全專案只有一份）==")
check("Extreme", CAP_TO_LEVEL["Extreme"], "extreme")
check("Severe", CAP_TO_LEVEL["Severe"], "critical")
check("Moderate", CAP_TO_LEVEL["Moderate"], "warning")
check("Minor", CAP_TO_LEVEL["Minor"], "info")
check("ai.py 引用同一份", ai.CAP_TO_LEVEL is CAP_TO_LEVEL, True)

print("\n== 官方紅色措辭 ==")
for text, want in [
    ("花蓮縣秀林鄉土石流紅色警戒，請立即撤離", True),
    ("臺南市淹水警戒紅色，請民眾注意", True),
    ("明日臺北市為紅色燈號，有連續出現38度高溫的機率", True),
    ("本區發布紅色警報", True),
    ("淹水警戒燈號為紅色，請往高處避難", True),
    ("土石流紅色警戒已解除", False),
    ("解除紅色警戒，恢復通行", False),
    ("紅色警戒調降為黃色警戒", False),
    ("臺南市為橙色燈號", False),
    ("交通號誌紅燈故障，請小心", False),
    ("原紅色警戒已解除。另發布黃色警戒", False),
    ("原黃色警戒已解除。另發布紅色警戒", True),
]:
    check(text, official_red(text), want)

print("\n== grade 的順序：紅色措辭 → CAP 等級 → 模型 ==")


def no_model(*a, **k):
    raise AssertionError("不該呼叫模型")


ai._generate = no_model
check("紅色措辭優先於 CAP Severe", ai.grade("土石流紅色警戒\n請撤離", "Severe"), ("extreme", "官方措辭"))
check("CAP Extreme", ai.grade("大規模豪雨", "Extreme"), ("extreme", "官方等級"))
check("CAP Severe", ai.grade("高溫", "Severe"), ("critical", "官方等級"))
check("解除紅色警戒不算，照 CAP", ai.grade("土石流紅色警戒已解除", "Minor"), ("info", "官方等級"))
check("模型的等級選項沒有 extreme", sorted(s.value for s in ai.Severity), ["critical", "info", "warning"])

print("\n== county_levels 用同一份對照表 ==")
xml = """<alert xmlns="urn:oasis:names:tc:emergency:cap:1.2"><info><severity>Extreme</severity><description>a</description>
<area><areaDesc>臺南市</areaDesc></area></info><info><severity>Severe</severity><description>b</description>
<area><areaDesc>南投縣</areaDesc></area></info></alert>"""
cap = parse_cap(xml)
check("county_levels", cap["county_levels"], {"tnn": "extreme", "nan": "critical"})

print(f"\n不符：{fails} 項")
sys.exit(1 if fails else 0)
