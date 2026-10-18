class WebRestore {
  WebRestore._();

  static final _savers = <String, Object? Function()>{};
  static Map<String, Object?> _pending = {};
  static int _busy = 0;
  static void Function()? _onIdle;

  static void register(String key, Object? Function() save) =>
      _savers[key] = save;

  static void unregister(String key, Object? Function() save) {
    if (identical(_savers[key], save)) _savers.remove(key);
  }

  static void load(Map<String, Object?> data) => _pending = data;

  static Object? take(String key) => _pending.remove(key);

  static Map<String, Object?> collect() {
    final data = <String, Object?>{..._pending};
    for (final e in _savers.entries) {
      final v = e.value();
      if (v == null) {
        data.remove(e.key);
      } else {
        data[e.key] = v;
      }
    }
    return data;
  }

  static void begin() => _busy++;

  static void end() {
    if (_busy > 0) _busy--;
    if (_busy == 0) {
      final f = _onIdle;
      _onIdle = null;
      f?.call();
    }
  }

  static void whenIdle(void Function() f) {
    if (_busy == 0) {
      f();
    } else {
      _onIdle = f;
    }
  }
}
