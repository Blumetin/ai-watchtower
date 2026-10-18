import copy
import os
import sys
from datetime import timedelta

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "functions"))
os.environ.setdefault("GOOGLE_CLOUD_PROJECT", "ai-watchtower-tw")
import main


class Ref:
    def __init__(self, db, col, id_): self.db, self.col, self.id = db, col, id_
    def set(self, data, merge=False):
        col = self.db.data.setdefault(self.col, {})
        col[self.id] = {**col.get(self.id, {}), **copy.deepcopy(data)} if merge else copy.deepcopy(data)
        self.db.writes += 1


class Col:
    def __init__(self, db, name): self.db, self.name = db, name
    def document(self, id_): return Ref(self.db, self.name, id_)


class FakeDB:
    def __init__(self): self.data, self.writes = {}, 0
    def collection(self, name): return Col(self, name)


class Broken:
    def collection(self, name): raise RuntimeError("firestore down")


def show(db, name):
    d = db.data["meta"][name]
    return {k: (type(v).__name__ if k.endswith("_at") else v) for k, v in sorted(d.items())}


def main_():
    db = FakeDB()
    print("== sync_status ==")
    main._write_status(db, "sync_status", ok=True, fields={"active_count": 59})
    ok_at = db.data["meta"]["sync_status"]["last_ok_at"]
    print("  成功：", show(db, "sync_status"))
    main._write_status(db, "sync_status", ok=False, error=TimeoutError("detail must not leak"))
    d = db.data["meta"]["sync_status"]
    print("  失敗：", show(db, "sync_status"))
    print("  失敗時保留上次筆數：", d["active_count"] == 59, "｜保留 last_ok_at：", d["last_ok_at"] == ok_at,
          "｜last_run_at 有更新：", d["last_run_at"] > ok_at, "｜錯誤只寫類型：", d["last_error"] == "TimeoutError")
    main._write_status(db, "sync_status", ok=True, fields={"active_count": 60})
    print("  恢復：", show(db, "sync_status"))

    print("\n== 狀態文件寫不進去不影響同步 ==")
    try:
        main._write_status(Broken(), "sync_status", ok=True, fields={"active_count": 1})
        print("  沒有丟出例外：True")
    except Exception as e:
        print("  丟出例外：", e)

    print("\n== quake_status 節流（每 2 分鐘一輪，最多 10 分鐘寫一次）==")
    db = FakeDB()
    main._quake_status["at"] = None
    same = {"written": 0, "significant": 7, "local": 16}
    print("  冷啟動第一輪寫入：", main._report_quake_status(db, same))
    print("  2 分鐘後、沒有新地震：", main._report_quake_status(db, same))
    print("  有新地震：", main._report_quake_status(db, {"written": 1, "significant": 7, "local": 17}))
    main._quake_status["at"] -= timedelta(minutes=10)
    print("  距上次滿 10 分鐘：", main._report_quake_status(db, same))
    print("  內容：", show(db, "quake_status"))
    writes_before = db.writes
    for _ in range(4):
        main._report_quake_status(db, same)
    print("  接下來 4 輪（8 分鐘）沒變化的寫入次數：", db.writes - writes_before)


if __name__ == "__main__":
    main_()
