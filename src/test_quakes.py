import copy
import os
import sys
from collections import Counter
from datetime import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "functions"))

from watchtower import qa, quakes


class Snap:
    def __init__(self, id_, data): self.id, self._d = id_, data
    @property
    def exists(self): return self._d is not None
    def to_dict(self): return copy.deepcopy(self._d)


class Ref:
    def __init__(self, db, col, id_): self.db, self.col, self.id = db, col, id_
    def get(self): return Snap(self.id, self.db.data.get(self.col, {}).get(self.id))
    def set(self, data): self.db.data.setdefault(self.col, {})[self.id] = copy.deepcopy(data)


class Query:
    def __init__(self, docs): self.docs = docs
    def stream(self): return [Snap(k, v) for k, v in self.docs]


class Col:
    def __init__(self, db, name): self.db, self.name = db, name
    def stream(self):
        self.db.reads += len(self.db.data.get(self.name, {}))
        return [Snap(k, v) for k, v in self.db.data.setdefault(self.name, {}).items()]
    def document(self, id_): return Ref(self.db, self.name, id_)
    def where(self, field, op, value):
        assert op == ">="
        return Query([(k, v) for k, v in self.db.data.get(self.name, {}).items() if v.get(field, "") >= value])


class Batch:
    def __init__(self, db): self.db, self.ops = db, []
    def set(self, ref, data, merge=False): self.ops.append((ref, data))
    def commit(self):
        for ref, data in self.ops:
            ref.set(data)


class FakeDB:
    def __init__(self): self.data, self.reads = {}, 0
    def collection(self, name): return Col(self, name)
    def batch(self): return Batch(self)


def main():
    print("執行時間：", datetime.now().isoformat(timespec="seconds"))
    data, counts = quakes.collect()
    print("\n== 下載（近 30 天）==", counts)
    by_type = Counter(q["report_type"] for q in data)
    print("  significant", by_type["significant"], "｜ local", by_type["local"])

    print("\n== 位置字串拆解 ==")
    for q in data:
        p = quakes.parse_location(q["location"])
        print(f"  {q['id']:<20} {q['location']}  →  {p}")
    bad = [q["id"] for q in data if not quakes.parse_location(q["location"])]
    print("  拆解失敗：", bad or "無")

    ids = [q["id"] for q in data]
    print("\n== 重複檢查 ==")
    print("  文件 ID 不重複：", len(ids) == len(set(ids)), f"（{len(ids)} 筆）")
    sig = [q for q in data if q["report_type"] == "significant"]
    overlap = [(l["id"], s["id"]) for l in data if l["report_type"] == "local"
               for s in sig if l["origin_time"] == s["origin_time"]]
    print("  local 與 significant 發震時間相同：", overlap or "無")

    db = FakeDB()
    print("\n== 第 1 輪（空資料庫）==", quakes.sync_quakes(db, data), "｜讀取文件數", db.reads)
    print("== 第 2 輪（同一份資料，同一執行個體）==", quakes.sync_quakes(db, data), "｜累計讀取", db.reads)
    quakes._seen.clear()
    print("== 第 3 輪（模擬冷啟動）==", quakes.sync_quakes(db, data), "｜累計讀取", db.reads)

    eq = db.data["earthquakes"]
    print("\n== 地名翻譯快取（place_names）==")
    for name, tr in sorted(db.data.get("place_names", {}).items()):
        print(f"  {name}: {tr}")

    print("\n== 115064 完整文件 ==")
    for k, v in sorted(eq.get("115064", {}).items()):
        print(f"  {k}: {v}")

    print("\n== 各筆位置兩語 ==")
    for i, d in sorted(eq.items(), key=lambda x: x[1]["origin_time"], reverse=True):
        langs = [l for l in ("en", "ja") if f"location_{l}" in d]
        print(f"  {i:<20} {d['report_type']:<11} M{d['magnitude']} {d['origin_time']}  語言 {langs}")
        for l in langs:
            print(f"      {l}: {d['location_' + l]}")
    missing = {l: sum(1 for d in eq.values() if f"location_{l}" not in d) for l in ("en", "ja")}
    print("  缺譯文筆數：", missing)

    qa.set_db(db)
    print("\n== qa.get_recent_quakes ==")
    r = qa.get_recent_quakes(days=30)
    print("  近 30 天全部：", r["total"], Counter(q["report_type"] for q in r["quakes"]))
    r5 = qa.get_recent_quakes(days=30, min_magnitude=5.0)
    print("  近 30 天規模 5.0 以上：", r5["total"], [(q["origin_time"], q["magnitude"], q["location"]) for q in r5["quakes"]])

    print("\n== 查不到地震的固定文字不會被當成提示外洩 ==")
    for lang in ("zh", "en", "ja"):
        for days, mag in ((1, 0), (7, 5)):
            t = qa.no_quakes(lang, days, mag)
            print(f"  {lang} days={days} mag={mag} leaked={qa.leaked(t)}：{t}")

    for q, lang in (("最近有比較大的地震嗎", "zh"), ("剛剛有地震嗎", "zh"),
                    ("Was there an earthquake just now?", "en"), ("さっき地震がありましたか", "ja")):
        a = qa.ask(q, lang)
        print(f"\n== qa.ask「{q}」（{lang}，假資料庫，alerts 為空）==")
        print("  route:", a.get("route"), "tools:", a.get("tools"))
        print("  答：", a["answer"])


if __name__ == "__main__":
    main()
