import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "functions"))

from watchtower.cap import for_alert, parse_cap

FIX = os.path.join(HERE, "data", "cap_fixtures")
fails = 0


def load(name):
    return parse_cap(open(os.path.join(FIX, name), encoding="utf-8").read())


def check(label, got, want):
    global fails
    ok = got == want
    fails += not ok
    print(f"  {'OK' if ok else 'NG'}  {label}：{got}" + ("" if ok else f"（應為 {want}）"))


print("== 醫院急門診：19 段 <info>，每段一家醫院，沒有行政區代碼、縣市在 areaDesc 地址裡 ==")
cap = load("HospitalReport_000194_20260926_20260925180000.cap")
print("  整份電文聯集：", cap["counties"])
for info in cap["infos"]:
    r = for_alert(cap, "急門診通報", info["description"])
    check(info["description"][10:30], (r["counties"], r["county_source"]), (info["counties"], "cap_info"))

print("\n== 停水：一份電文兩處停水，各自在不同縣市 ==")
cap = load("TWC_water_202609241550.cap")
check("新營區台一線", for_alert(cap, "停水", "辦理新營區台一線290K+200等汰換管線工程斷水聯絡施工")["counties"], ["tnn"])
check("三峽忠義二加壓站", for_alert(cap, "停水", "忠義二加壓站更換流量計停水施工")["counties"], ["nwt"])

print("\n== 停水：同一處停水分成好幾段（不同村里），要取這幾段的聯集 ==")
cap = load("TWC_water_202609221520.cap")
yk = for_alert(cap, "停水", "為辦理永康區大仁街等汰換管線工程(大灣路37巷6弄及大灣路41巷)，屆時因施工需停水，致使永康行政區部份停水，請貴用戶配合")
check("永康（多段同一 description）", yk["counties"], ["tnn"])
cy = [i for i in cap["infos"] if "cyq" in i["counties"]][0]["description"]
check("嘉義縣水上鄉", for_alert(cap, "停水", cy)["counties"], ["cyq"])

print("\n== 高溫：電文只有一種 description，分地區給不同等級，全部採用 ==")
cap = load("fifows_heat_202609251754.cap")
r = for_alert(cap, "高溫", "天氣晴朗炎熱")
check("縣市（與整份電文相同）", r["counties"], cap["counties"])
check("各縣市等級（與整份電文相同）", r["county_levels"], cap["county_levels"])
check("來源", r["county_source"], "cap")

print("\n== 對不到任何一段：先從文字找縣市，找不到才用整份電文 ==")
cap = load("TWC_water_202609241550.cap")
r = for_alert(cap, "停水", "高雄市某處停水")
check("文字有縣市", (r["counties"], r["county_source"]), (["khh"], "text"))
r = for_alert(cap, "停水", "完全對不上的內容")
check("文字也沒有：整份電文", (r["counties"], r["county_source"]), (cap["counties"], "cap_all"))

print("\n== 縣市簡稱（找不到全名時才用；新竹、嘉義只認全名）==")
from watchtower.cap import counties_from_text
for text, want in [
    ("海洋委員會\\海洋保育署：宜蘭頭城籍「全億財16」漁船外海失火案", ["ila"]),
    ("新北市三峽區", ["nwt"]),
    ("嘉義", []),
    ("高雄", ["khh"]),
    ("臺北市大安區基隆路", ["tpe"]),
    ("新北三峽與臺北交界", ["nwt"]),
    ("台東外海", ["ttt"]),
    ("馬祖北竿", ["lie"]),
    ("新竹外海", []),
]:
    check(text, counties_from_text(text), want)

print("\n== 電文 <instruction>（10/7）：挑段方式同 for_alert，對不到是哪一段時不取 ==")
from watchtower.cap import instruction_for
NS = 'xmlns="urn:oasis:names:tc:emergency:cap:1.2"'
info = lambda d, i: f"<info><description>{d}</description>" + (f"<instruction>{i}</instruction>" if i else "") + "</info>"
one = parse_cap(f"<alert {NS}>{info('甲地停水', '請儲水')}</alert>")
check("只有一種 description：取它的指示", instruction_for(one, "甲地停水"), "請儲水")
two = parse_cap(f"<alert {NS}>{info('甲地停水', '甲地請儲水')}{info('乙地停水', '乙地請儲水')}</alert>")
check("多種 description：取對得到那段的指示", instruction_for(two, "乙地停水"), "乙地請儲水")
check("多種 description、都對不到：空字串", instruction_for(two, "丙地停水"), "")
check("沒有 instruction：空字串", instruction_for(parse_cap(f"<alert {NS}>{info('甲地停水', '')}</alert>"), "甲地停水"), "")

print(f"\n不符：{fails} 項")
sys.exit(1 if fails else 0)
