import hashlib
import json
import sys

NAME_TO_CODE = {
    '基隆市': 'kee', '臺北市': 'tpe', '新北市': 'nwt', '桃園市': 'tao', '新竹市': 'hsz',
    '新竹縣': 'hsq', '苗栗縣': 'mia', '臺中市': 'txg', '彰化縣': 'cha', '南投縣': 'nan',
    '雲林縣': 'yun', '嘉義市': 'cyi', '嘉義縣': 'cyq', '臺南市': 'tnn', '高雄市': 'khh',
    '屏東縣': 'pif', '宜蘭縣': 'ila', '花蓮縣': 'hua', '臺東縣': 'ttt', '澎湖縣': 'pen',
    '金門縣': 'kin', '連江縣': 'lie',
}


def seg_dist(p, a, b):
    (x, y), (x1, y1), (x2, y2) = p, a, b
    dx, dy = x2 - x1, y2 - y1
    if dx == dy == 0:
        return ((x - x1) ** 2 + (y - y1) ** 2) ** 0.5
    t = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
    px, py = x1 + t * dx, y1 + t * dy
    return ((x - px) ** 2 + (y - py) ** 2) ** 0.5


def dp(pts, tol):
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        s, e = stack.pop()
        best, idx = 0.0, -1
        for i in range(s + 1, e):
            d = seg_dist(pts[i], pts[s], pts[e])
            if d > best:
                best, idx = d, i
        if best > tol and idx > 0:
            keep[idx] = True
            stack += [(s, idx), (idx, e)]
    return [p for p, k in zip(pts, keep) if k]


def simplify_ring(ring, tol, nd=5):
    pts = ring[:-1] if ring[0] == ring[-1] else ring
    if len(pts) < 3:
        return None
    far = max(range(len(pts)), key=lambda i: (pts[i][0] - pts[0][0]) ** 2 + (pts[i][1] - pts[0][1]) ** 2)
    a = dp(pts[: far + 1], tol)
    b = dp(pts[far:] + [pts[0]], tol)
    out = a[:-1] + b[:-1]
    if len(out) < 3:
        return None
    out.append(out[0])
    return [[round(x, nd), round(y, nd)] for x, y in out]


def _cross(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def self_intersects(ring):
    n = len(ring) - 1
    segs = [(ring[i], ring[i + 1]) for i in range(n)]
    for i in range(n):
        a, b = segs[i]
        for j in range(i + 2, n):
            if i == 0 and j == n - 1:
                continue
            c, d = segs[j]
            if (max(a[0], b[0]) < min(c[0], d[0]) or max(c[0], d[0]) < min(a[0], b[0])
                    or max(a[1], b[1]) < min(c[1], d[1]) or max(c[1], d[1]) < min(a[1], b[1])):
                continue
            d1, d2 = _cross(a, b, c), _cross(a, b, d)
            d3, d4 = _cross(c, d, a), _cross(c, d, b)
            if d1 * d2 < 0 and d3 * d4 < 0:
                return True
    return False


def simplify_valid(ring, tol, nd=5):
    t = tol
    while t >= tol / 256:
        out = simplify_ring(ring, t, nd)
        if out is None or not self_intersects(out):
            return out, t
        t /= 2
    pts = ring if ring[0] == ring[-1] else ring + [ring[0]]
    return [[round(x, nd), round(y, nd)] for x, y in pts], 0.0


def ring_key(ring):
    return frozenset((round(x, 6), round(y, 6)) for x, y in ring)


def _signed_area(ring):
    return sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(ring, ring[1:])) / 2


def _inside(pt, ring):
    x, y = pt
    hit = False
    for (x1, y1), (x2, y2) in zip(ring, ring[1:]):
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            hit = not hit
    return hit


def read_shp(path):
    import struct
    import os
    base = path[:-4]
    dbf_path = next(base + e for e in ('.dbf', '.DBF', '.Dbf') if os.path.exists(base + e))
    dbf = open(dbf_path, 'rb').read()
    nrec, hlen, rlen = struct.unpack('<IHH', dbf[4:12])
    fields, off = [], 32
    while dbf[off] != 0x0D:
        fname = dbf[off:off + 11].split(b'\0')[0].decode().strip()
        fields.append((fname, dbf[off + 16]))
        off += 32
    names = []
    for r in range(nrec):
        rec, pos, row = dbf[hlen + r * rlen: hlen + (r + 1) * rlen], 1, {}
        for fname, flen in fields:
            row[fname] = rec[pos:pos + flen].decode('utf-8', 'replace').strip()
            pos += flen
        names.append(row['COUNTYNAME'])
    shp = open(path, 'rb').read()
    out, off = [], 100
    for name in names:
        _, clen = struct.unpack('>II', shp[off:off + 8])
        body = shp[off + 8: off + 8 + clen * 2]
        off += 8 + clen * 2
        stype, = struct.unpack('<i', body[:4])
        assert stype == 5, f'{name} 不是多邊形（type {stype}）'
        nparts, npts = struct.unpack('<ii', body[36:44])
        parts = list(struct.unpack(f'<{nparts}i', body[44:44 + 4 * nparts])) + [npts]
        p0 = 44 + 4 * nparts
        xy = struct.unpack(f'<{2 * npts}d', body[p0:p0 + 16 * npts])
        rings = [[[xy[2 * i], xy[2 * i + 1]] for i in range(parts[k], parts[k + 1])] for k in range(nparts)]
        outers = [[r] for r in rings if _signed_area(r) < 0]
        for h in (r for r in rings if _signed_area(r) >= 0):
            owner = next(o for o in outers if _inside(h[0], o[0]))
            owner.append(h)
        out.append((name, outers))
    return out


def main(src, dst, tol=0.004):
    raw = open(src, 'rb').read()
    out = {}
    feats = []
    for name, polys in read_shp(src):
        feats.append((NAME_TO_CODE[name.replace('台', '臺')], polys))
    outers = {}
    reduced = []
    for code, polys in feats:
        for poly in polys:
            o, t = simplify_valid(poly[0], tol)
            outers[ring_key(poly[0])] = o
            if o is not None and t != tol:
                reduced.append((code, t))
    shared_holes = 0
    dropped = 0
    for code, polys in feats:
        result = []
        biggest = max(polys, key=lambda p: abs(_signed_area(p[0])))
        for poly in polys:
            xs, ys = [p[0] for p in poly[0]], [p[1] for p in poly[0]]
            if poly is not biggest and ((max(xs) - min(xs)) ** 2 + (max(ys) - min(ys)) ** 2) ** 0.5 < tol:
                dropped += 1
                continue
            outer = outers[ring_key(poly[0])]
            if outer is None:
                continue
            holes = []
            for r in poly[1:]:
                k = ring_key(r)
                if k in outers:
                    shared_holes += 1
                    h = outers[k]
                else:
                    h, t = simplify_valid(r, tol)
                if h:
                    holes.append(h)
            result.append([outer] + holes)
        out.setdefault(code, []).extend(result)
    assert set(out) == set(NAME_TO_CODE.values()), set(NAME_TO_CODE.values()) - set(out)
    for code, polys in out.items():
        assert polys, f'{code} 沒有任何多邊形'
        for poly in polys:
            for ring in poly:
                assert len(ring) >= 4 and ring[0] == ring[-1], f'{code} 有未閉合或過短的環'
    with open(dst, 'w', encoding='utf-8') as fh:
        json.dump(out, fh, separators=(',', ':'))
    meta = {
        'source_file': src.split('/')[-1],
        'source_sha256': hashlib.sha256(raw).hexdigest(),
        'tolerance_deg': tol,
        'dataset': '內政部國土測繪中心「直轄市、縣市界線(TWD97經緯度)」',
        'dataset_url': 'https://data.gov.tw/dataset/7442',
        'download_url': 'https://www.tgos.tw/tgos/VirtualDir/Product/1cd4f4c9-6b01-4cf9-bf6c-23a73aa17d24/直轄市、縣(市)界線1140318.zip',
        'download_zip_sha256': '9ff4d337e03a711d7e17caaf4d0c46a0fe2c6bd3660b321a2e35123030d8491c',
        'version': '1140318',
        'license': '政府資料開放授權條款－第 1 版（https://data.gov.tw/license）',
        'shared_holes': shared_holes,
        'dropped_islets': dropped,
        'reduced_tolerance_rings': [f'{c}:{t:g}' for c, t in reduced],
        'polygons': sum(len(p) for p in out.values()),
        'holes': sum(len(poly) - 1 for p in out.values() for poly in p),
        'points': sum(len(r) for p in out.values() for poly in p for r in poly),
    }
    with open(dst.replace('.json', '.meta.json'), 'w', encoding='utf-8') as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)
    print(dst, meta)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 0.004)
