import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/push_prefs.dart' show countyName;
import '../l10n/app_localizations.dart';
import '../theme.dart';

typedef Ring = List<Offset>;
typedef CountyShapes = Map<String, List<List<Ring>>>;

Future<CountyShapes>? _cache;

Future<CountyShapes> loadCountyShapes() =>
    _cache ??= _load().catchError((Object e) {
      _cache = null;
      throw e;
    });

Future<CountyShapes> _load() async {
  final raw = await rootBundle.loadString('assets/data/tw_counties.json');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in json.entries)
      key: [
        for (final poly in value as List)
          [
            for (final ring in poly as List)
              [
                for (final p in ring as List)
                  Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
              ],
          ],
      ],
  };
}

class TaiwanCountyMap extends StatelessWidget {
  final Map<String, String?> levels;
  final String lang;

  final String? title;

  final double heightFactor;

  final double? minHeight;

  final double? fixedHeight;

  final double? legendFontSize;

  final bool moreLabelSlots;
  const TaiwanCountyMap({
    super.key,
    required this.levels,
    required this.lang,
    this.title,
    this.heightFactor = 0.32,
    this.minHeight,
    this.fixedHeight,
    this.legendFontSize,
    this.moreLabelSlots = false,
  });

  double _height(BuildContext context) {
    if (fixedHeight != null) return fixedHeight!;
    final h = MediaQuery.sizeOf(context).height * heightFactor;
    return minHeight == null ? h : math.max(h, minHeight!);
  }

  static Color colorOf(String? level) =>
      level == null ? AppColors.unrated : severityColor(level);

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: loadCountyShapes(),
    builder: (context, snap) {
      final shapes = snap.data;
      if (snap.hasError) return const SizedBox.shrink();
      if (shapes == null) {
        return SizedBox(height: _height(context));
      }
      final t = AppLocalizations.of(context)!;
      final names = [
        for (final MapEntry(key: c, value: l) in levels.entries)
          '${countyName(c, lang)}${lang == 'zh' || lang == 'ja' ? '：' : ': '}${severityLabel(t, l) ?? t.levelUnrated}',
      ];
      final maxH = _height(context);
      final map = Semantics(
        label: names.join(lang == 'zh' || lang == 'ja' ? '、' : ', '),
        child: SizedBox(
          height: maxH,
          width: double.infinity,
          child: CustomPaint(
            painter: _Painter(
              shapes: shapes,
              levels: levels,
              lang: lang,
              labelStyle: Theme.of(context).textTheme.labelMedium!,
              moreLabelSlots: moreLabelSlots,
            ),
          ),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
          ],
          map,
          const SizedBox(height: 8),
          CountyLevelLegend(levels: levels, fontSize: legendFontSize),
        ],
      );
    },
  );
}

class _Painter extends CustomPainter {
  final CountyShapes shapes;
  final Map<String, String?> levels;
  final String lang;
  final TextStyle labelStyle;
  final bool moreLabelSlots;
  _Painter({
    required this.shapes,
    required this.levels,
    required this.lang,
    required this.labelStyle,
    this.moreLabelSlots = false,
  }) : super(repaint: PaintingBinding.instance.systemFonts);

  static const _outlying = {'kin', 'lie'};
  
  static const _main = Rect.fromLTRB(119.25, 21.85, 122.1, 25.35);

  @override
  void paint(Canvas canvas, Size size) {
    final box = math.min(size.width, size.height) * 0.26;
    final insets = {
      for (final (i, code) in ['lie', 'kin'].indexed)
        code: Rect.fromLTWH(8, 8 + i * (box + 8), box, box),
    };
    _drawRegion(
      canvas,
      Offset.zero & size,
      _main,
      {
        for (final e in shapes.entries)
          if (!_outlying.contains(e.key)) e.key: e.value,
      },
      allowed: Offset.zero & size,
      forbidden: insets.values.toList(),
    );
    for (final MapEntry(key: code, value: r) in insets.entries) {
      final all = shapes[code];
      if (all == null) continue;
      double size(List<Ring> p) => _bounds([p]).size.longestSide;
      final main = _bounds([all.reduce((a, b) => size(a) >= size(b) ? a : b)])
          .center;
      final polys = [
        for (final p in all)
          if ((_bounds([p]).center - main).distance < 0.8) p,
      ];
      canvas.drawRect(
        r,
        Paint()
          ..color = AppColors.outlineVariant
          ..style = PaintingStyle.stroke,
      );
      TextPainter label(double fontSize) => TextPainter(
        text: TextSpan(
          text: _mapLabel(
            code,
            lang,
          ).replaceFirst('Lienchiang', 'Lien\u00ADchiang'),
          style: labelStyle.copyWith(
            fontSize: fontSize,
            color: levels.containsKey(code)
                ? AppColors.onSurface
                : AppColors.textMuted,
            fontWeight: levels.containsKey(code) ? FontWeight.w700 : null,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      var tp = label(12);
      if (tp.width > box - 4) {
        final fit = (12 * (box - 4) / tp.width).floorToDouble().clamp(
          9.0,
          12.0,
        );
        tp.dispose();
        tp = label(fit);
      }
      if (tp.width > box - 4) {
        final t = tp.text;
        tp.dispose();
        tp = TextPainter(text: t, textDirection: TextDirection.ltr, maxLines: 2)
          ..layout(maxWidth: box - 4);
      }
      _drawRegion(
        canvas,
        Rect.fromLTRB(
          r.left + 6,
          r.top + 6,
          r.right - 6,
          math.max(r.top + 6, r.bottom - tp.height - 4),
        ),
        _bounds(polys).inflate(0.03),
        {code: polys},
        labelHighlighted: false,
      );
      canvas
        ..save()
        ..clipRect(r);
      tp.paint(canvas, Offset(r.left + 2, r.bottom - tp.height - 2));
      canvas.restore();
    }
  }

  
  static Rect _bounds(List<List<Ring>> polys) {
    final pts = polys.expand((p) => p.first);
    return Rect.fromLTRB(
      pts.map((p) => p.dx).reduce(math.min),
      pts.map((p) => p.dy).reduce(math.min),
      pts.map((p) => p.dx).reduce(math.max),
      pts.map((p) => p.dy).reduce(math.max),
    );
  }

  
  static final _anchors = <String, Offset>{};
  static Offset _anchorOf(String code, List<Ring> poly) =>
      _anchors[code] ??= _poleOfInaccessibility(poly);

  
  static Offset _poleOfInaccessibility(List<Ring> poly) {
    final b = _bounds([poly]);
    final k = math.cos(b.center.dy * math.pi / 180);
    double edgeDist(Offset p) {
      var inside = false;
      var best = double.infinity;
      for (final ring in poly) {
        for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
          final a = ring[i], c = ring[j];
          if ((a.dy > p.dy) != (c.dy > p.dy) &&
              p.dx < (c.dx - a.dx) * (p.dy - a.dy) / (c.dy - a.dy) + a.dx) {
            inside = !inside;
          }
          final ax = a.dx * k, ay = a.dy, cx = c.dx * k, cy = c.dy;
          final px = p.dx * k, py = p.dy;
          final dx = cx - ax, dy = cy - ay;
          final len2 = dx * dx + dy * dy;
          final t = len2 == 0
              ? 0.0
              : (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
          final ex = ax + t * dx - px, ey = ay + t * dy - py;
          best = math.min(best, ex * ex + ey * ey);
        }
      }
      return inside ? math.sqrt(best) : -math.sqrt(best);
    }

    var center = b.center;
    var w = b.width, h = b.height;
    var bestP = center;
    var bestD = edgeDist(center);
    for (var round = 0; round < 4; round++) {
      const n = 16;
      for (var i = 0; i <= n; i++) {
        for (var j = 0; j <= n; j++) {
          final p = Offset(
            center.dx - w / 2 + w * i / n,
            center.dy - h / 2 + h * j / n,
          );
          final d = edgeDist(p);
          if (d > bestD) {
            bestD = d;
            bestP = p;
          }
        }
      }
      center = bestP;
      w /= 4;
      h /= 4;
    }
    return bestP;
  }

  
  static bool _inside(List<Ring> poly, Offset p) {
    var inside = false;
    for (final ring in poly) {
      for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        final a = ring[i], c = ring[j];
        if ((a.dy > p.dy) != (c.dy > p.dy) &&
            p.dx < (c.dx - a.dx) * (p.dy - a.dy) / (c.dy - a.dy) + a.dx) {
          inside = !inside;
        }
      }
    }
    return inside;
  }

  
  void _drawRegion(
    Canvas canvas,
    Rect dst,
    Rect geo,
    Map<String, List<List<Ring>>> regions, {
    bool labelHighlighted = true,
    Rect? allowed,
    List<Rect> forbidden = const [],
  }) {
    final k = math.cos(geo.center.dy * math.pi / 180);
    final w = geo.width * k, h = geo.height;
    final scale = math.min(dst.width / w, dst.height / h);
    final ox = dst.left + (dst.width - w * scale) / 2;
    final oy = dst.top + (dst.height - h * scale) / 2;
    Offset proj(Offset p) => Offset(
      ox + (p.dx - geo.left) * k * scale,
      oy + (geo.bottom - p.dy) * scale,
    );

    final fill = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white;
    final labels = <(String, Offset, bool, List<Ring>?)>[];
    final dots = <(Offset, Color, Color?)>[];
    for (final MapEntry(key: code, value: rings) in regions.entries) {
      final on = levels.containsKey(code);
      fill.color = on
          ? TaiwanCountyMap.colorOf(levels[code])
          : AppColors.surfaceContainerHigh;
      for (final poly in rings) {
        final path = Path()..fillType = PathFillType.evenOdd;
        for (final ring in poly) {
          path.addPolygon([for (final p in ring) proj(p)], true);
        }
        canvas.drawPath(path, fill);
        final border = on ? severityBorder(levels[code]) : null;
        canvas.drawPath(
          path,
          border == null ? stroke : (borderPaint..color = border),
        );
      }
      if (on && labelHighlighted) {
        Rect? b;
        List<Ring>? mainPoly;
        for (final poly in rings) {
          final pb = _bounds([poly]);
          if (b == null || pb.width * pb.height > b.width * b.height) {
            b = pb;
            mainPoly = poly;
          }
        }
        final screen = Rect.fromPoints(proj(b!.topLeft), proj(b.bottomRight));
        final nameSize = (TextPainter(
          text: TextSpan(
            text: countyName(code, 'zh'),
            style: labelStyle.copyWith(fontSize: 12, height: 1.1),
          ),
          textDirection: TextDirection.ltr,
        )..layout()).size;
        final small =
            screen.width < nameSize.width * 0.75 ||
            screen.height < nameSize.height * 1.5;
        if (small) {
          dots.add((screen.center, fill.color, severityBorder(levels[code])));
        }
        labels.add((code, screen.center, small, small ? null : mainPoly));
      }
    }
    for (final (at, color, border) in dots) {
      canvas.drawCircle(at, 5, Paint()..color = color);
      canvas.drawCircle(
        at,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = border ?? Colors.white,
      );
    }
    final dotRects = [
      for (final (at, _, _) in dots) Rect.fromCircle(center: at, radius: 7),
    ];
    final style = labelStyle.copyWith(fontSize: 12, height: 1.1);
    final n = labels.length;
    final fills = [
      for (final (code, _, _, _) in labels)
        TextPainter(
          text: TextSpan(text: _mapLabel(code, lang), style: style),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    bool usable(Rect c) =>
        (allowed == null ||
            (allowed.contains(c.topLeft) && allowed.contains(c.bottomRight))) &&
        !forbidden.any((f) => f.overlaps(c)) &&
        !dotRects.any((d) => d.overlaps(c));
    List<Rect> around(int i, Offset c, {required bool far}) {
      final f = fills[i];
      final small = labels[i].$3;
      final dy = small ? f.height / 2 + 8 : f.height + 1;
      final dx = f.width / 2 + (small ? 8 : 2);
      final offsets = far
          ? [
              Offset(2 * dx, 0),
              Offset(-2 * dx, 0),
              Offset(dx, 2 * dy),
              Offset(-dx, 2 * dy),
              Offset(dx, -2 * dy),
              Offset(-dx, -2 * dy),
            ]
          : [
              if (!small) Offset.zero,
              if (small) ...[Offset(dx, 0), Offset(-dx, 0)],
              Offset(0, dy),
              Offset(0, -dy),
              if (!small) ...[Offset(dx, 0), Offset(-dx, 0)],
              Offset(dx, dy),
              Offset(-dx, dy),
              Offset(dx, -dy),
              Offset(-dx, -dy),
              Offset(0, 2 * dy),
              Offset(0, -2 * dy),
            ];
      return [
        for (final o in offsets)
          Rect.fromCenter(center: c + o, width: f.width, height: f.height),
      ].where(usable).toList();
    }

    final nearOpts = [
      for (var i = 0; i < n; i++) around(i, labels[i].$2, far: false),
    ];
    final origOpts = [
      for (var i = 0; i < n; i++)
        [
          ...nearOpts[i],
          if (moreLabelSlots) ...around(i, labels[i].$2, far: true),
        ],
    ];
    bool clear(List<Rect?> placed, Rect c) =>
        !placed.any((p) => p != null && p.overlaps(c.inflate(2)));
    List<Rect?> greedy(List<int> order, List<List<Rect>> opts) {
      final placed = List<Rect?>.filled(n, null);
      for (final i in order) {
        placed[i] = opts[i].where((c) => clear(placed, c)).firstOrNull;
      }
      return placed;
    }

    int skipped(List<Rect?> p) => p.where((r) => r == null).length;
    final orig = greedy([for (var i = 0; i < n; i++) i], origOpts);
    var placed = orig;
    if (skipped(orig) > 0) {
      final allOpts = [
        for (var i = 0; i < n; i++)
          [
            ...origOpts[i],
            if (labels[i].$4 case final poly?)
              ...around(i, proj(_anchorOf(labels[i].$1, poly)), far: false),
            if (!moreLabelSlots) ...around(i, labels[i].$2, far: true),
          ],
      ];
      List<Rect?> solve(List<int> order) {
        final p = greedy(order, allOpts);
        for (final i in order) {
          if (p[i] != null) continue;
          for (final c in allOpts[i]) {
            final blockers = [
              for (final (k, r) in p.indexed)
                if (r != null && r.overlaps(c.inflate(2))) k,
            ];
            if (blockers.isEmpty) {
              p[i] = c;
              break;
            }
            if (blockers.length > 2) continue;
            final before = [for (final m in blockers) p[m]];
            p[i] = c;
            for (final m in blockers) {
              p[m] = null;
            }
            var ok = true;
            for (final m in blockers) {
              final moved = nearOpts[m].where((o) => clear(p, o)).firstOrNull;
              if (moved == null) {
                ok = false;
                break;
              }
              p[m] = moved;
            }
            if (ok) break;
            p[i] = null;
            for (final (k, m) in blockers.indexed) {
              p[m] = before[k];
            }
          }
        }
        return p;
      }

      bool better(List<Rect?> p, List<Rect?> than) {
        if (skipped(p) >= skipped(than)) return false;
        for (var i = 0; i < n; i++) {
          if (orig[i] != null && p[i] == null) return false;
        }
        return true;
      }

      var order = [for (var i = 0; i < n; i++) i];
      final first = solve(order);
      if (better(first, placed)) placed = first;
      for (var round = 0; round < 3 && skipped(placed) > 0; round++) {
        final missing = [
          for (final i in order)
            if (placed[i] == null) i,
        ];
        order = [
          ...missing,
          for (final i in order)
            if (placed[i] != null) i,
        ];
        final next = solve(order);
        if (!better(next, placed)) break;
        placed = next;
      }
    }

    Offset unproj(Offset p) => Offset(
      (p.dx - ox) / (k * scale) + geo.left,
      geo.bottom - (p.dy - oy) / scale,
    );
    double segDist(Offset p, Offset a, Offset b) {
      final ab = b - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final t = len2 == 0
          ? 0.0
          : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
      return (a + ab * t - p).distance;
    }

    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.9);
    final pinHalo = Paint()..color = Colors.white;
    final pin = Paint()..color = AppColors.onSurfaceVariant;
    final leader = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.onSurfaceVariant;
    for (var i = 0; i < n && scale > 0; i++) {
      final r = placed[i];
      if (r == null || r == orig[i]) continue;
      final (code, at, small, poly) = labels[i];
      Offset edgeOf(Offset t) =>
          Offset(t.dx.clamp(r.left, r.right), t.dy.clamp(r.top, r.bottom));
      if (small) {
        final edge = edgeOf(at);
        final d = edge - at;
        if (d.distance <= 16) continue;
        final from = at + d / d.distance * 8;
        canvas
          ..drawLine(from, edge, halo)
          ..drawLine(from, edge, leader);
        continue;
      }
      final touches = [
        r.center,
        r.topLeft,
        r.topRight,
        r.bottomLeft,
        r.bottomRight,
      ].any((p) => _inside(poly!, unproj(p)));
      if (touches) continue;
      final pole = proj(_anchorOf(code, poly!));
      Offset? nearest;
      var best = double.infinity;
      final ring = [for (final g in poly.first) proj(g)];
      for (var a = 0, b = ring.length - 1; a < ring.length; b = a++) {
        final ab = ring[a] - ring[b];
        final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
        final t = len2 == 0
            ? 0.0
            : (((r.center - ring[b]).dx * ab.dx +
                          (r.center - ring[b]).dy * ab.dy) /
                      len2)
                  .clamp(0.0, 1.0);
        final q = ring[b] + ab * t;
        final dist = (q - r.center).distance;
        if (dist < best) {
          best = dist;
          nearest = q;
        }
      }
      final inward = pole - nearest!;
      final candidates = [
        for (var d = 4.0; d < inward.distance; d += 4)
          nearest + inward / inward.distance * d,
        pole,
      ].where((t) => _inside(poly, unproj(t))).toList();
      if (candidates.isEmpty) continue;
      double clearance(Offset a, Offset b) {
        var m = double.infinity;
        for (final (d, _, _) in dots) {
          m = math.min(m, segDist(d, a, b));
        }
        return m;
      }

      bool outward(Offset a, Offset t) {
        const e = 1e-6;
        final d = t - a;
        final inX = (a.dx - r.left).abs() < e
            ? d.dx > 0
            : (a.dx - r.right).abs() < e
            ? d.dx < 0
            : true;
        final inY = (a.dy - r.top).abs() < e
            ? d.dy > 0
            : (a.dy - r.bottom).abs() < e
            ? d.dy < 0
            : true;
        return !(inX && inY);
      }

      (Offset, Offset)? route;
      var bestClear = -1.0;
      search:
      for (final t in candidates) {
        if (r.inflate(1).contains(t)) continue;
        for (final a in [
          edgeOf(t),
          r.bottomCenter,
          r.topCenter,
          r.centerLeft,
          r.centerRight,
          r.bottomRight,
          r.topRight,
          r.bottomLeft,
          r.topLeft,
        ]) {
          if ((a - t).distance < 1 || !outward(a, t)) continue;
          final c = clearance(a, t);
          if (c > bestClear) {
            bestClear = c;
            route = (a, t);
          }
          if (c >= 8) break search;
        }
      }
      if (route == null) continue;
      final (start, target) = route;
      canvas
        ..drawLine(start, target, halo)
        ..drawLine(start, target, leader)
        ..drawCircle(target, 3, pinHalo)
        ..drawCircle(target, 2, pin);
    }
    final outline = TextPainter(textDirection: TextDirection.ltr);
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < n; i++) {
      final r = placed[i];
      if (r != null) {
        outline
          ..text = TextSpan(
            text: _mapLabel(labels[i].$1, lang),
            style: style.copyWith(foreground: outlinePaint),
          )
          ..layout()
          ..paint(canvas, r.topLeft);
        fills[i].paint(canvas, r.topLeft);
      }
      fills[i].dispose();
    }
    outline.dispose();
  }

  @override
  bool shouldRepaint(_Painter old) =>
      !mapEquals(old.levels, levels) ||
      old.lang != lang ||
      old.labelStyle != labelStyle ||
      old.moreLabelSlots != moreLabelSlots;
}


class CountyLevelLegend extends StatelessWidget {
  final Map<String, String?> levels;
  final double? fontSize;
  const CountyLevelLegend({super.key, required this.levels, this.fontSize});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final present = levels.values.toSet();
    final items = [
      for (final l in const ['extreme', 'critical', 'warning', 'info', null])
        if (present.contains(l)) (l, severityLabel(t, l) ?? t.levelUnrated),
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final (l, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: TaiwanCountyMap.colorOf(l),
                  borderRadius: BorderRadius.circular(3),
                  border: switch (severityBorder(l)) {
                    final c? => Border.all(color: c, width: 1.5),
                    null => null,
                  },
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: text.labelMedium!.copyWith(fontSize: fontSize),
              ),
            ],
          ),
      ],
    );
  }
}




final _enSuffix = RegExp(r' (County|City)$');

String _mapLabel(String code, String lang) {
  final full = countyName(code, lang);
  if (lang != 'en') return full;
  return switch (code) {
    'hsz' || 'cyi' => full,
    'hsq' || 'cyq' => full.replaceFirst(' County', ' Co.'),
    _ => full.replaceFirst(_enSuffix, ''),
  };
}
