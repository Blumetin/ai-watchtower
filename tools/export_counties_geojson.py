
import json
import sys

from simplify_counties import NAME_TO_CODE, _signed_area, read_shp, ring_key, simplify_valid


def orient(ring, ccw):
    return ring if (_signed_area(ring) > 0) == ccw else ring[::-1]


def main(src, dst, tol=0.001):
    feats = read_shp(src)
    outers = {}
    for _, polys in feats:
        for poly in polys:
            outers[ring_key(poly[0])] = simplify_valid(poly[0], tol, 6)[0]
    features, stats = [], {'polygons': 0, 'holes': 0, 'points': 0, 'dropped_islets': 0}
    for name, polys in feats:
        name = name.replace('台', '臺')
        biggest = max(polys, key=lambda p: abs(_signed_area(p[0])))
        coords = []
        for poly in polys:
            xs, ys = [p[0] for p in poly[0]], [p[1] for p in poly[0]]
            if poly is not biggest and ((max(xs) - min(xs)) ** 2 + (max(ys) - min(ys)) ** 2) ** 0.5 < tol:
                stats['dropped_islets'] += 1
                continue
            outer = outers[ring_key(poly[0])]
            if outer is None:
                continue
            rings = [orient(outer, True)]
            for h in poly[1:]:
                hr = outers.get(ring_key(h)) or simplify_valid(h, tol, 6)[0]
                if hr:
                    rings.append(orient(hr, False))
            coords.append(rings)
            stats['polygons'] += 1
            stats['holes'] += len(rings) - 1
            stats['points'] += sum(len(r) for r in rings)
        features.append({
            'type': 'Feature',
            'properties': {'COUNTYNAME': name, 'code': NAME_TO_CODE[name]},
            'geometry': {'type': 'MultiPolygon', 'coordinates': coords},
        })
    with open(dst, 'w', encoding='utf-8') as fh:
        json.dump({'type': 'FeatureCollection', 'features': features}, fh, ensure_ascii=False, separators=(',', ':'))
    print(dst, stats)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 0.001)
