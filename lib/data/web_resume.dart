import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../web/page_visibility.dart';

class WebResumeRefresher {
  WebResumeRefresher._();

  static const threshold = Duration(minutes: 5);

  static const _retryDelay = Duration(minutes: 1);
  static const _maxAttempts = 4;

  static const _tokenTimeout = Duration(seconds: 30);

  static bool _started = false;
  static DateTime? _hiddenSince;

  static int _wanted = 0;
  static int _done = 0;

  static bool _reconnect = false;

  static bool _networkOff = false;

  static int _attempts = 0;
  static Timer? _retry;
  static bool _running = false;
  static bool _rerun = false;

  static void start() {
    if (!kIsWeb || _started) return;
    _started = true;
    if (pageHidden()) _hiddenSince = DateTime.now();
    onPageVisibilityChange((hidden) {
      if (hidden) {
        _hiddenSince ??= DateTime.now();
        _retry?.cancel();
        _retry = null;
        return;
      }
      final since = _hiddenSince;
      _hiddenSince = null;
      if (since != null && DateTime.now().difference(since) >= threshold) {
        _wanted++;
      }
      _attempts = 0;
      _kick();
    });
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
      while (!pageHidden() && await _step()) {}
    } finally {
      _running = false;
      if (_rerun) {
        _rerun = false;
        _kick();
      }
    }
  }

  static Future<bool> _step() async {
    if (_networkOff) return _enableNetwork();
    if (_reconnect) {
      _networkOff = true;
      try {
        await FirebaseFirestore.instance.disableNetwork();
      } catch (e) {
        debugPrint('Firestore: disableNetwork failed: $e');
      }
      _reconnect = false;
      return _enableNetwork();
    }
    if (_wanted == _done || _attempts >= _maxAttempts) return false;
    final target = _wanted;
    _attempts++;
    try {
      await FirebaseAppCheck.instance.getToken(true).timeout(_tokenTimeout);
    } catch (e) {
      debugPrint('App Check: refresh after resume failed ($_attempts): $e');
      if (_attempts < _maxAttempts && !pageHidden()) {
        _retry?.cancel();
        _retry = Timer(_retryDelay, () {
          _retry = null;
          if (!pageHidden()) _kick();
        });
      }
      return false;
    }
    debugPrint('App Check: token refreshed after resume');
    _done = target;
    _reconnect = true;
    return true;
  }

  static Future<bool> _enableNetwork() async {
    try {
      await FirebaseFirestore.instance.enableNetwork();
      _networkOff = false;
      return true;
    } catch (e) {
      debugPrint('Firestore: enableNetwork failed: $e');
      return false;
    }
  }
}
