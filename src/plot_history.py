import json, sys
from datetime import datetime, timezone
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager

for name in ("PingFang TC", "Heiti TC", "Arial Unicode MS"):
    if any(f.name == name for f in font_manager.fontManager.ttflist):
        plt.rcParams["font.family"] = name
        break
plt.rcParams["axes.unicode_minus"] = False

TW_GEOJSON = __import__("os").path.join(__import__("os").path.dirname(__file__), "data", "tw_counties_nlsc_1140318.geojson")


def draw_taiwan(ax):
    from matplotlib.patches import Polygon as MplPolygon
    gj = json.load(open(TW_GEOJSON, encoding="utf-8"))
    for feat in gj["features"]:
        geom = feat["geometry"]
        polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        for poly in polys:
            ring = poly[0]
            ax.add_patch(MplPolygon(ring, closed=True, facecolor="#f2efe6", edgecolor="#444444",
                                    linewidth=0.6, zorder=0))


CITIES = {"臺北": (121.56, 25.04), "花蓮": (121.60, 23.98), "臺中": (120.68, 24.14),
          "臺南": (120.21, 23.00), "高雄": (120.30, 22.63), "臺東": (121.15, 22.76)}

NOTABLE = [("1999 集集", "1999-09-20"), ("2002 331", "2002-03-31"), ("2006 恆春", "2006-12-26"),
           ("2016 美濃", "2016-02-05"), ("2018 花蓮", "2018-02-06"), ("2022 池上", "2022-09-17"),
           ("2024 花蓮", "2024-04-02"), ("2025 宜蘭", "2025-12-27")]


def load(path):
    feats = json.load(open(path))["features"]
    rows = []
    for f in feats:
        p, g = f["properties"], f["geometry"]["coordinates"]
        if p["mag"] is None:
            continue
        rows.append((datetime.fromtimestamp(p["time"] / 1000, tz=timezone.utc), g[0], g[1], g[2], p["mag"]))
    rows.sort()
    return rows


def epicenter_map(rows, out):
    lon = np.array([r[1] for r in rows]); lat = np.array([r[2] for r in rows])
    dep = np.array([r[3] for r in rows]); mag = np.array([r[4] for r in rows])
    fig, ax = plt.subplots(figsize=(7.5, 8.5), dpi=150)
    ax.set_facecolor("#e8f1f8")
    draw_taiwan(ax)
    sc = ax.scatter(lon, lat, s=(mag - 4) ** 3 * 6 + 4, c=dep, cmap="turbo_r",
                    alpha=0.85, edgecolors="none", vmin=0, vmax=150, zorder=2)
    for name, (x, y) in CITIES.items():
        ax.plot(x, y, marker="s", color="black", ms=4, zorder=3)
        ax.annotate(name, (x, y), xytext=(4, 4), textcoords="offset points", fontsize=9, zorder=3)
    cb = plt.colorbar(sc, ax=ax, shrink=0.7, pad=0.02)
    cb.set_label("深度（公里）")
    for m in (5, 6, 7):
        ax.scatter([], [], s=(m - 4) ** 3 * 6 + 4, c="gray", alpha=0.6, label=f"M{m}")
    ax.legend(title="規模", loc="lower left", frameon=True)
    ax.set_xlim(119, 123); ax.set_ylim(21, 26)
    ax.set_xlabel("經度"); ax.set_ylabel("緯度")
    ax.set_title(f"臺灣周邊 M4.5+ 震央分布（1996–2026，USGS，共 {len(rows):,} 起）", fontsize=12)
    ax.set_aspect(1 / np.cos(np.deg2rad(23.5)))
    ax.grid(alpha=0.3)
    fig.text(0.01, 0.005, "點大小＝規模，顏色＝深度。空白不代表安全：目錄完整度與規模門檻都會影響視覺印象。",
             fontsize=7.5, va="bottom", color="dimgray")
    fig.tight_layout(rect=(0, 0.02, 1, 1)); fig.savefig(out, bbox_inches="tight"); plt.close(fig)


def magnitude_timeline(rows, out):
    t = [r[0] for r in rows]; mag = np.array([r[4] for r in rows]); dep = np.array([r[3] for r in rows])
    fig, ax = plt.subplots(figsize=(11, 5), dpi=150)
    sc = ax.scatter(t, mag, s=(mag - 4) ** 3 * 4 + 3, c=dep, cmap="turbo_r", alpha=0.85, edgecolors="none", vmin=0, vmax=150)
    cb = plt.colorbar(sc, ax=ax, pad=0.01); cb.set_label("深度（公里）")
    for i, (label, day) in enumerate(NOTABLE):
        d0 = datetime.fromisoformat(day).replace(tzinfo=timezone.utc)
        cands = [r for r in rows if abs((r[0] - d0).total_seconds()) < 3 * 86400]
        if not cands:
            continue
        ev = max(cands, key=lambda r: r[4])
        ax.annotate(f"{label}\nM{ev[4]:.1f}", (ev[0], ev[4]), xytext=(0, 14 + 22 * (i % 2)), textcoords="offset points",
                    ha="center", fontsize=8, arrowprops=dict(arrowstyle="-", color="gray", lw=0.6))
    ax.set_ylabel("規模"); ax.set_xlabel("年份")
    ax.set_ylim(4.3, 8.2)
    ax.set_title("臺灣周邊 M4.5+ 規模—時間分布（1996–2026，USGS）", fontsize=12)
    ax.grid(alpha=0.3)
    ax.text(0.005, 0.02, "大地震後的垂直叢集＝餘震序列。", transform=ax.transAxes, fontsize=8, color="dimgray")
    fig.tight_layout(); fig.savefig(out, bbox_inches="tight"); plt.close(fig)


def stats(rows):
    mag = np.array([r[4] for r in rows])
    years = (rows[-1][0] - rows[0][0]).days / 365.25
    return {"總數": len(rows), "年均": round(len(rows) / years, 1),
            "M5+": int((mag >= 5).sum()), "M6+": int((mag >= 6).sum()), "M7+": int((mag >= 7).sum()),
            "最大": max(rows, key=lambda r: r[4])}


if __name__ == "__main__":
    rows = load(sys.argv[1]); out = sys.argv[2]
    epicenter_map(rows, f"{out}/epicenter_map.png")
    magnitude_timeline(rows, f"{out}/magnitude_timeline.png")
    print(stats(rows))
