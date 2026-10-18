import 'dart:convert';
import 'dart:js_interop';

import 'web_restore.dart';
import 'web_restore_format.dart';

extension type _Storage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

extension type _Location(JSObject _) implements JSObject {
  external void reload();
}

@JS('localStorage')
external _Storage get _storage;

@JS('sessionStorage')
external _Storage get _session;

@JS('location')
external _Location get _location;

@JS('watchtowerMapsLang')
external String? get _mapsLang;

@JS('watchtowerLang')
external String? get _startupLang;

const _key = 'watchtower.lang';

bool _valid(String? v) => v == 'zh' || v == 'en' || v == 'ja';

String? startupWebLang() {
  try {
    final v = _startupLang;
    return _valid(v) ? v : null;
  } catch (_) {
    return null;
  }
}

@JS('watchtowerRestore')
external String? get _restoreRaw;

@JS('watchtowerRestore')
external set _restoreRaw(String? v);

const _restoreKey = 'watchtower.restore';
const _restoreVersion = 1;

void loadWebRestore() {
  try {
    final raw = _restoreRaw;
    _restoreRaw = null;
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is Map &&
        decoded['v'] == _restoreVersion &&
        decoded['data'] is Map) {
      WebRestore.load(normalizeRestore(decoded['data'] as Map));
    }
  } catch (_) {
  }
}

String? _requested;

void saveWebLang(String code) {
  if (!_valid(code)) return;
  _requested = code;
  try {
    _storage.setItem(_key, code);
    if (_storage.getItem(_key) != code) return;
  } catch (_) {
    return;
  }
  WebRestore.whenIdle(_reloadIfNeeded);
}

void _reloadIfNeeded() {
  try {
    final code = _requested;
    final maps = _mapsLang;
    if (code == null || maps == null || maps == code) return;
    _storage.setItem(_key, code);
    if (_storage.getItem(_key) != code) return;
    final data = WebRestore.collect();
    if (data.isNotEmpty) {
      final json = jsonEncode({
        'v': _restoreVersion,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'data': data,
      });
      _session.setItem(_restoreKey, json);
      if (_session.getItem(_restoreKey) != json) {
        _session.removeItem(_restoreKey);
        return;
      }
    } else {
      _session.removeItem(_restoreKey);
    }
    _location.reload();
  } catch (_) {
    try {
      _session.removeItem(_restoreKey);
    } catch (_) {}
  }
}
