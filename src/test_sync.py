import copy
import json
import os
import sys
from datetime import datetime, timedelta, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "functions"))

os.environ.setdefault("GOOGLE_CLOUD_PROJECT", "ai-watchtower-tw")
import main
from watchtower.fetch_ncdr import fetch_alerts


class Snap:
    def __init__(self, id_, data): self.id, self._d = id_, data
    def to_dict(self): return copy.deepcopy(self._d)


class Ref:
    def __init__(self, db, col, id_): self.db, self.col, self.id = db, col, id_


class Col:
    def __init__(self, db, name): self.db, self.name = db, name
    def stream(self): return [Snap(k, v) for k, v in self.db.data.setdefault(self.name, {}).items()]
    def document(self, id_): return Ref(self.db, self.name, id_)


class Batch:
    def __init__(self, db): self.db, self.ops = db, []
    def set(self, ref, data, merge=False): self.ops.append(("set", ref, data))
    def delete(self, ref): self.ops.append(("delete", ref, None))
    def commit(self):
        for kind, ref, data in self.ops:
            col = self.db.data.setdefault(ref.col, {})
            if kind == "set":
                col[ref.id] = {**col.get(ref.id, {}), **copy.deepcopy(data)}
            else:
                col.pop(ref.id, None)


class FakeDB:
    def __init__(self): self.data = {}
    def collection(self, name): return Col(self, name)
    def batch(self): return Batch(self)


if __name__ == "__main__":
    raw = json.load(open(sys.argv[1])) if len(sys.argv) > 1 else fetch_alerts()
    db = FakeDB()
    print("第 1 輪（空資料庫）：", main.sync_alerts(db, raw))
    print("第 2 輪（同一份 feed）：", main.sync_alerts(db, raw))
    uid = next(iter(db.data["alerts"]))
    db.data["alerts"][uid]["ai_summary_en"] = "(AI field kept?)"
    raw_id = db.data["alerts"][uid]["raw_id"]
    for r in raw:
        if r["id"] == raw_id:
            r["expires"] = "2020/1/1 上午 12:00:00"
    print("第 3 輪（一則到期）：", main.sync_alerts(db, raw))
    moved = db.data["history"].get(uid, {})
    print("  搬到 history：", bool(moved), "｜AI 欄位保留：", moved.get("ai_summary_en") == "(AI field kept?)",
          "｜ended_at、purge_at：", "ended_at" in moved, "purge_at" in moved,
          "｜purge_at 距今天數：", (moved["purge_at"] - datetime.now(timezone.utc)).days if moved else None)
    print("  alerts 還有：", len(db.data["alerts"]), "｜history：", len(db.data["history"]))

    from watchtower.normalize import pipeline
    feed = json.load(open(sys.argv[1])) if len(sys.argv) > 1 else fetch_alerts()
    active = [a for a in pipeline(feed) if a.status == "active"]
    db2 = FakeDB()
    main.sync_alerts(db2, feed)
    print("\n真實 feed：生效中", len(active), "則｜alerts", len(db2.data.get("alerts", {})), "則｜一致：",
          len(active) == len(db2.data.get("alerts", {})))
    groups = {}
    for a in active:
        groups.setdefault(a.raw_id, []).append(a.uid)
    multi = {k: v for k, v in groups.items() if len(v) > 1}
    print("  同一 raw_id 多則生效的群組：", len(multi), "組、共", sum(len(v) for v in multi.values()), "則，全部在 alerts：",
          all(u in db2.data["alerts"] for v in multi.values() for u in v))

    base = next(r for r in feed if r["id"] == active[0].raw_id)
    twin = dict(base, summary=base["summary"] + "（另一地區的獨立通知）")
    db3 = FakeDB()
    main.sync_alerts(db3, [base, twin])
    print("  用例：同一 raw_id、內容不同的兩則都生效 → alerts", len(db3.data.get("alerts", {})), "則（應為 2）")
