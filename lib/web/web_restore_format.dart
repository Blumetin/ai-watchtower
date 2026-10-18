import '../screens/qa_screen.dart';

Map<String, Object?> normalizeRestore(Map<Object?, Object?> raw) {
  final out = <String, Object?>{};
  for (final e in raw.entries) {
    final key = e.key;
    if (key is! String) continue;
    final v = switch (key) {
      'qa' => QaScreen.normalizeRestore(e.value),
      'quake.tab' => _tab(e.value, 2),
      'prep.tab' => _tab(e.value, 20),
      'alerts.list' || 'quake.recent' => _offset(e.value),
      'alerts.filter' => _filter(e.value),
      'quake.history' => _history(e.value),
      _ => null,
    };
    if (v != null) out[key] = v;
  }
  return out;
}

int? _tab(Object? v, int length) => v is int && v >= 0 && v < length ? v : null;

double? _offset(Object? v) =>
    v is num && v.isFinite && v >= 0 ? v.toDouble() : null;

String? _shortText(Object? v) => v is String && v.length <= 64 ? v : null;

Map<String, Object?>? _filter(Object? v) {
  if (v is! Map) return null;
  final g = v['g'], c = v['c'];
  if (g != null && _shortText(g) == null) return null;
  if (c != null && _shortText(c) == null) return null;
  if (g == null && c == null) return null;
  return {'g': g, 'c': c};
}

Map<String, Object?>? _history(Object? v) {
  if (v is! Map) return null;
  final mag = v['mag'], cam = v['cam'];
  if (mag is! num || !mag.isFinite || mag < 4.5 || mag > 7.7) return null;
  if (((mag * 10).round() - mag * 10).abs() > 1e-6) return null;
  final ok =
      cam is List &&
      cam.length == 3 &&
      cam.every((x) => x is num && x.isFinite) &&
      (cam[0] as num).abs() <= 85 &&
      (cam[1] as num).abs() <= 180 &&
      (cam[2] as num) >= 5 &&
      (cam[2] as num) <= 12;
  return {
    'mag': mag.toDouble(),
    if (ok) 'cam': [for (final x in cam) (x as num).toDouble()],
  };
}
