import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher, TextLeadingDistribution;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

part 'splash_timeline.dart';

class SplashOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const SplashOverlay({super.key, required this.onDone});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

const _bg = Color(0xFFECEFF1);
const _ink = Color(0xFF37474F);
const _red = Color(0xFFC62828);

const _plain = Color(0xFFCFD8DC);

const _u = 2.25;
const _box = 100 * _u;

const _hold = Duration(milliseconds: 300);

class _Track {
  final String? id;
  final String? each;
  final double start;
  final double dur;
  final double staggerZh;
  final double staggerEn;
  final String ease;
  final Map<String, (double, double)> p;
  const _Track({
    this.id,
    this.each,
    required this.start,
    required this.dur,
    required this.staggerZh,
    required this.staggerEn,
    required this.ease,
    required this.p,
  });
}

class _Timeline {
  final double total;
  final double last;
  final List<_Track> tracks;
  const _Timeline({
    required this.total,
    required this.last,
    required this.tracks,
  });
}

typedef _Seg = ({
  double start,
  double end,
  double from,
  double to,
  String ease,
});

class _Values {
  final Map<String, List<_Seg>> _seg = {};

  _Values(_Timeline tl, {required bool latin, required int words}) {
    List<String> ids(String each) => switch (each) {
      'wm' => [for (var i = 0; i < words; i++) 'wm_$i'],
      'line' => const ['line_1', 'line_2', 'line_3'],
      _ => const [],
    };
    for (final tr in tl.tracks) {
      final stagger = latin ? tr.staggerEn : tr.staggerZh;
      final items = tr.each == null
          ? [(tr.id!, tr.start)]
          : [
              for (final (i, id) in ids(tr.each!).indexed)
                (id, tr.start + i * stagger),
            ];
      for (final (id, start) in items) {
        tr.p.forEach((k, ft) {
          (_seg['$id.$k'] ??= []).add((
            start: start,
            end: start + tr.dur,
            from: ft.$1,
            to: ft.$2,
            ease: tr.ease,
          ));
        });
      }
    }
    for (final list in _seg.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }
  }

  static double _default(String id, String k) {
    if (k == 'o') {
      return id.startsWith('line_') || id.startsWith('wm_') ? 0 : 1;
    }
    if (k == 's' || k == 'tint') return 1;
    final rest = _lineRest[id];
    if (rest != null) {
      return switch (k) {
        'cx' => rest.cx,
        'cy' => rest.cy,
        'w' => rest.w,
        'h' => rest.h,
        _ => 0,
      };
    }
    return 0;
  }

  double at(String id, String k, double t) {
    final a = _seg['$id.$k'];
    if (a == null) return _default(id, k);
    if (t < a.first.start) return a.first.from;
    var s = a.first;
    for (final seg in a.reversed) {
      if (t >= seg.start) {
        s = seg;
        break;
      }
    }
    if (t >= s.end) return s.to;
    final x = (t - s.start) / (s.end - s.start);
    final eased = _eases[s.ease]?.transform(x) ?? (x > 0 ? 1.0 : 0.0);
    return s.from + (s.to - s.from) * eased;
  }
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;
  late bool _reduce;
  late _Timeline _tl;
  _Values? _values;
  String? _valuesKey;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    _reduce =
        MediaQuery.disableAnimationsOf(context) ||
        PlatformDispatcher.instance.accessibilityFeatures.reduceMotion;
    _tl = _reduce ? _reduced : _normal;
    _c =
        AnimationController(
            vsync: this,
            duration: Duration(milliseconds: (_tl.total * 1000).round()),
            animationBehavior: AnimationBehavior.preserve,
          )
          ..addListener(_finishWhenRevealed)
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) _finish();
          });
    _revealAt = _tl.tracks
        .where((tr) => tr.id == 'bg')
        .map((tr) => tr.start + tr.dur)
        .fold(_tl.total, (a, b) => a < b ? a : b);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(_hold, () {
        if (mounted && !_done) _c!.forward();
      });
    });
  }

  late double _revealAt;

  void _finishWhenRevealed() {
    if (_c!.value * _tl.total >= _revealAt) _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  void _skip() {
    _c!.value = 1;
    _finish();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c!;
    final t = AppLocalizations.of(context)!;
    final latin = Localizations.localeOf(context).languageCode == 'en';
    final words = t.appTitle.trim().split(RegExp(r'\s+'));
    final List<String?> pieces = latin
        ? [
            for (final (i, w) in words.indexed) ...[if (i > 0) null, w],
          ]
        : [
            for (final ch in t.appTitle.trim().characters)
              ch.trim().isEmpty ? null : ch,
          ];
    final units = pieces.whereType<String>().toList();
    final key = '${latin ? 'en' : 'cjk'}:${units.length}';
    final values = _valuesKey == key
        ? _values!
        : (_values = _Values(_tl, latin: latin, words: units.length));
    _valuesKey = key;

    final size = MediaQuery.sizeOf(context);
    final boxLeft = size.width / 2 - _box / 2;
    final boxTop = size.height / 2 - _box / 2;
    final wordTop =
        boxTop +
        _u * ((_reduce ? _tailTipReduced : _tailTipNormal) + _wordGapU);
    final wordStyle = Theme.of(context).textTheme.headlineSmall!.copyWith(
      color: _ink,
      fontWeight: FontWeight.w700,
      fontSize: latin ? 24 : 33,
      height: 1.25,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final charPad = latin ? 0.0 : 33 * 0.04;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: BlockSemantics(
        child: Semantics(
          container: true,
          label: t.appTitle,
          onTap: _skip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _skip,
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: c,
                builder: (context, _) {
                  final time = c.value * _tl.total;
                  double v(String id, String k) => values.at(id, k, time);
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: v('bg', 'o').clamp(0.0, 1.0),
                          child: const ColoredBox(color: _bg),
                        ),
                      ),
                      Positioned.fill(
                        child: Opacity(
                          opacity: v('stage', 'o').clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, v('stage', 'ty') * _u),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: boxLeft,
                                  top: boxTop,
                                  width: _box,
                                  height: _box,
                                  child: CustomPaint(painter: _MarkPainter(v)),
                                ),
                                Positioned(
                                  left: 24,
                                  right: 24,
                                  top: wordTop,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (final (i, unit) in _numbered(
                                          pieces,
                                        ))
                                          if (unit == null)
                                            Text(' ', style: wordStyle)
                                          else
                                            Transform.translate(
                                              offset: Offset(
                                                0,
                                                v('wm_$i', 'ty') * _u,
                                              ),
                                              child: Opacity(
                                                opacity: v(
                                                  'wm_$i',
                                                  'o',
                                                ).clamp(0.0, 1.0),
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: charPad,
                                                  ),
                                                  child: Text(
                                                    unit,
                                                    style: wordStyle,
                                                  ),
                                                ),
                                              ),
                                            ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}


Iterable<(int, String?)> _numbered(List<String?> pieces) sync* {
  var i = 0;
  for (final p in pieces) {
    if (p == null) {
      yield (-1, null);
    } else {
      yield (i++, p);
    }
  }
}

class _MarkPainter extends CustomPainter {
  final double Function(String id, String k) v;
  const _MarkPainter(this.v);

  static void _scaleAbout(Canvas canvas, double x, double y, double s) {
    canvas.translate(x, y);
    canvas.scale(s);
    canvas.translate(-x, -y);
  }

  static Paint _fill(Color color, [double alpha = 1]) =>
      Paint()..color = color.withValues(alpha: alpha.clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    canvas.translate(0, v('mark', 'ty'));
    _scaleAbout(canvas, 50, 50, v('mark', 's'));

    canvas.save();
    _scaleAbout(canvas, 48, 46.48, v('bubble', 's'));
    final ink = _fill(_ink);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17.64, 24.4, 60.72, 44.16),
        const Radius.circular(12.88),
      ),
      ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(29.6, 64.88)
        ..lineTo(27.76, 82.36)
        ..lineTo(44.32, 67.64)
        ..close(),
      ink,
    );
    for (final id in const ['line_1', 'line_2', 'line_3']) {
      _line(canvas, id);
    }
    final barO = v('excl_bar', 'o');
    if (barO > 0) {
      canvas.save();
      _scaleAbout(canvas, 48, 42.8, v('excl_bar', 's'));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(43.86, 32.68, 8.28, 20.24),
          const Radius.circular(4.14),
        ),
        _fill(Colors.white, barO),
      );
      canvas.restore();
    }
    final dotO = v('excl_dot', 'o');
    if (dotO > 0) {
      canvas.save();
      _scaleAbout(canvas, 48, 60.28, v('excl_dot', 's'));
      canvas.drawCircle(
        const Offset(48, 60.28),
        4.42,
        _fill(Colors.white, dotO),
      );
      canvas.restore();
    }
    canvas.restore();

    canvas.save();
    canvas.translate(v('badge', 'tx'), v('badge', 'ty'));
    _scaleAbout(canvas, 71.2, 28.8, v('badge', 's'));
    canvas.drawCircle(const Offset(71.2, 28.8), 8.5, _fill(_red));
    canvas.drawCircle(
      const Offset(71.2, 28.8),
      8.5,
      Paint()
        ..color = _bg
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.restore();
  }

  void _line(Canvas canvas, String id) {
    final o = v(id, 'o');
    if (o <= 0) return;
    final w = v(id, 'w');
    final h = v(id, 'h');
    final tint = v(id, 'tint');
    final wipe = v(id, 'wipe');
    canvas.save();
    canvas.translate(v(id, 'cx'), v(id, 'cy'));
    canvas.rotate(v(id, 'r') * math.pi / 180);
    if (tint > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w, height: h),
          Radius.elliptical(math.min(w, h) / 2, h / 2),
        ),
        _fill(_lineRest[id]!.tint, o * tint),
      );
    }
    final ww = wipe * w;
    if (ww >= 0.001) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w / 2, -h / 2, ww, h),
          Radius.elliptical(math.min(ww, h) / 2, h / 2),
        ),
        _fill(_plain, o),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => true;
}
