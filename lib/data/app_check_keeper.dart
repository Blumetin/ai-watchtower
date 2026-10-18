import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppCheckKeeper {
  AppCheckKeeper._();

  static const _lead = Duration(minutes: 10);

  static const _fallbackCheck = Duration(minutes: 15);

  static const _minGap = Duration(seconds: 30);

  static const _backoffStart = Duration(minutes: 1);
  static const _backoffMax = Duration(minutes: 30);
  static const _networkRetry = Duration(minutes: 1);
  static const _tokenTimeout = Duration(seconds: 30);

  static final ValueNotifier<int> reconnected = ValueNotifier(0);

  static bool _started = false;
  static bool _visible = true;
  static bool _running = false;
  static bool _rerun = false;
  static Timer? _timer;

  static String? _lastToken;
  static DateTime? _expiresAt;

  static DateTime? _recheckAt;

  static bool _forceNext = false;

  static bool _eventPending = false;

  static bool _needReconnect = false;

  static bool _networkOff = false;

  static DateTime _nextFetchAllowed = DateTime.fromMillisecondsSinceEpoch(0);
  static DateTime _nextNetworkAllowed = DateTime.fromMillisecondsSinceEpoch(0);
  static Duration _backoff = _backoffStart;

  // ignore: unused_field
  static AppLifecycleListener? _lifecycle;
  // ignore: unused_field
  static StreamSubscription<String?>? _tokenSub;

  
  static void start() {
    if (kIsWeb || _started) return;
    _started = true;
    
    final state = WidgetsBinding.instance.lifecycleState;
    _visible =
        state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    _lifecycle = AppLifecycleListener(
      onShow: () {
        _visible = true;
        _kick();
      },
      onResume: () {
        _visible = true;
        _kick();
      },
      onHide: () => _visible = false,
      onPause: () => _visible = false,
    );
    _tokenSub = FirebaseAppCheck.instance.onTokenChange.listen((token) {
      if (token != null && token.isNotEmpty && token != _lastToken) {
        _eventPending = true;
        _kick();
      }
    }, onError: (Object e) => debugPrint('App Check: onTokenChange error: $e'));
    _kick();
  }

  static void _kick() {
    if (_running) {
      _rerun = true;
      return;
    }
    unawaited(_run());
  }

  static Future<void> _run() async {
    _running = true;
    try {
      
      while ((_visible || _networkOff) && await _step()) {}
    } catch (e) {
      debugPrint('App Check keeper: $e');
    } finally {
      _running = false;
      if (_rerun) {
        _rerun = false;
        _kick();
      }
    }
  }

  
  static Future<bool> _step() async {
    final now = DateTime.now();
    if (_networkOff || _needReconnect) {
      if (now.isBefore(_nextNetworkAllowed)) {
        _schedule(_nextNetworkAllowed);
        return false;
      }
      return _networkOff ? _enableNetwork() : _disableNetwork();
    }
    if (!_visible) return false;

    
    
    if (_eventPending) {
      if (now.isBefore(_nextFetchAllowed)) {
        _schedule(_nextFetchAllowed);
        return false;
      }
      final r = await _read(false, source: 'event');
      
      if (r == null || !_visible) return false;
      _eventPending = false;
      if (_usable(r) && r.token != _lastToken) {
        _adopt(r, 'event');
        return true;
      }
    }

    final exp = _expiresAt;
    if (_lastToken != null && exp != null && exp.difference(now) > _lead) {
      _schedule(exp.subtract(_lead));
      return false;
    }
    final recheck = _recheckAt;
    if (_lastToken != null &&
        exp == null &&
        recheck != null &&
        now.isBefore(recheck)) {
      _schedule(recheck);
      return false;
    }
    if (now.isBefore(_nextFetchAllowed)) {
      _schedule(_nextFetchAllowed);
      return false;
    }

    if (!_forceNext) {
      final cached = await _read(false, source: 'cache');
      if (!_visible) return false;
      if (cached == null) {
        _forceNext = true;
        return false;
      }
      if (_usable(cached)) {
        _adopt(cached, 'cache');
        return true;
      }
      
    }

    if (!_visible) return false;
    final fresh = await _read(true, source: 'force');
    if (fresh == null) {
      _forceNext = true;
      return false;
    }
    if (!_usable(fresh)) {
      
      _failed('refreshed token expires too soon');
      _forceNext = true;
      return false;
    }
    _adopt(fresh, 'force');
    return true;
  }

  
  static bool _usable(AppCheckTokenResult r) {
    final exp = r.expirationTime;
    return exp == null || exp.difference(DateTime.now()) > _lead;
  }

  
  static Future<AppCheckTokenResult?> _read(
    bool force, {
    required String source,
  }) async {
    try {
      final r = await FirebaseAppCheck.instance
          .getTokenResult(force)
          .timeout(_tokenTimeout);
      final exp = r?.expirationTime;
      if (r == null ||
          r.token.isEmpty ||
          (exp != null && !exp.isAfter(DateTime.now()))) {
        _failed('$source: no valid token');
        return null;
      }
      return r;
    } catch (e) {
      
      _failed('$source: $e');
      return null;
    }
  }

  
  static void _adopt(AppCheckTokenResult r, String source) {
    _backoff = _backoffStart;
    _nextFetchAllowed = DateTime.fromMillisecondsSinceEpoch(0);
    _forceNext = false;
    _expiresAt = r.expirationTime;
    _recheckAt = _expiresAt == null ? DateTime.now().add(_fallbackCheck) : null;
    if (r.token == _lastToken) {
      return;
    }
    _lastToken = r.token;
    debugPrint('App Check: token from $source, expires $_expiresAt');
    
    
    _needReconnect = true;
  }

  static void _failed(Object reason) {
    _nextFetchAllowed = DateTime.now().add(_backoff);
    debugPrint(
      'App Check: token fetch failed ($reason), next try $_nextFetchAllowed',
    );
    final doubled = _backoff * 2;
    _backoff = doubled > _backoffMax ? _backoffMax : doubled;
    _schedule(_nextFetchAllowed);
  }

  static void _schedule(DateTime at) {
    _timer?.cancel();
    var wait = at.difference(DateTime.now());
    if (wait < _minGap) wait = _minGap;
    _timer = Timer(wait, () {
      _timer = null;
      _kick();
    });
  }

  static Future<bool> _disableNetwork() async {
    try {
      await FirebaseFirestore.instance.disableNetwork();
    } catch (e) {
      _networkFailed('disableNetwork', e);
      return false;
    }
    _needReconnect = false;
    _networkOff = true;
    return true;
  }

  static Future<bool> _enableNetwork() async {
    try {
      await FirebaseFirestore.instance.enableNetwork();
    } catch (e) {
      _networkFailed('enableNetwork', e);
      return false;
    }
    _networkOff = false;
    reconnected.value++;
    debugPrint('Firestore: reconnected (${reconnected.value})');
    return true;
  }

  static void _networkFailed(String op, Object e) {
    _nextNetworkAllowed = DateTime.now().add(_networkRetry);
    debugPrint('Firestore: $op failed: $e, retry $_nextNetworkAllowed');
    _schedule(_nextNetworkAllowed);
  }
}
