import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alert_repository.dart' show alertUidPattern;
import 'push_prefs.dart';

typedef PushNotice = ({String uid, String title, String body});

class PushService {
  PushService._();
  static final instance = PushService._();

  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool _enabled = false;
  bool get enabled => _enabled;

  final openUid = ValueNotifier<String?>(null);

  final _foreground = StreamController<PushNotice>.broadcast();

  Stream<PushNotice> get foreground => _foreground.stream;
  final _shownInForeground = <String>{};

  static const _kSubscribed = 'push.subscribed';

  Future<void> init() async {
    if (!platformSupported || _enabled) return;
    try {
      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      FirebaseMessaging.instance.onTokenRefresh.listen((_) => _resync());
      _enabled = true;
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions();
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _open(initial);
    } catch (e) {
      debugPrint('Push: init failed: $e');
    }
  }

  static String? _uidOf(RemoteMessage m) {
    final uid = m.data['uid'];
    return uid is String && alertUidPattern.hasMatch(uid) ? uid : null;
  }

  void _open(RemoteMessage m) {
    final uid = _uidOf(m);
    if (uid != null) openUid.value = uid;
  }

  void _onForeground(RemoteMessage m) {
    final uid = _uidOf(m);
    if (uid == null) return;
    if (_shownInForeground.length > 200) _shownInForeground.clear();
    if (!_shownInForeground.add(uid)) return;
    _foreground.add((
      uid: uid,
      title: m.notification?.title ?? m.data['title'] as String? ?? '',
      body: m.notification?.body ?? m.data['body'] as String? ?? '',
    ));
  }

  Future<bool?> permission() async {
    if (!_enabled) return null;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return switch (s.authorizationStatus) {
        AuthorizationStatus.notDetermined => null,
        final status => _granted(status),
      };
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermission({bool userAction = false}) async {
    if (!_enabled) return false;
    try {
      final m = FirebaseMessaging.instance;
      final status = (await m.getNotificationSettings()).authorizationStatus;
      final ask =
          status == AuthorizationStatus.notDetermined ||
          (userAction &&
              status == AuthorizationStatus.denied &&
              defaultTargetPlatform == TargetPlatform.android);
      if (!ask) return _granted(status);
      return _granted((await m.requestPermission()).authorizationStatus);
    } catch (e) {
      debugPrint('Push: permission request failed: $e');
      return false;
    }
  }

  static bool _granted(AuthorizationStatus s) =>
      s == AuthorizationStatus.authorized ||
      s == AuthorizationStatus.provisional;

  ({PushPrefs prefs, String lang})? _pending;
  ({PushPrefs prefs, String lang})? _last;
  bool _syncing = false;
  Timer? _apnsRetry;
  int _apnsTries = 0;

  Future<void> sync(PushPrefs prefs, String lang, {bool retry = false}) async {
    if (!_enabled) return;
    if (!retry) _apnsTries = 0;
    _pending = (prefs: prefs, lang: lang);
    _last = _pending;
    if (_syncing) return;
    _syncing = true;
    try {
      while (_pending != null) {
        final job = _pending!;
        _pending = null;
        final want = await permission() == true
            ? job.prefs.topics(job.lang)
            : <String>{};
        await _apply(want);
      }
    } catch (e) {
      debugPrint('Push: sync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  void _resync() {
    final last = _last;
    if (last != null) unawaited(sync(last.prefs, last.lang, retry: true));
  }

  Future<void> _apply(Set<String> want) async {
    final m = FirebaseMessaging.instance;
    final sp = await SharedPreferences.getInstance();
    final have = {...?sp.getStringList(_kSubscribed)};
    if (have.length == want.length && have.containsAll(want)) return;
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await m.getAPNSToken() == null) {
      debugPrint('Push: APNs token not ready, topics not synced');
      if (_apnsTries < 12 && (_apnsRetry?.isActive != true)) {
        _apnsTries++;
        _apnsRetry = Timer(const Duration(seconds: 5), _resync);
      }
      return;
    }
    _apnsRetry?.cancel();
    _apnsRetry = null;
    Future<void> save() =>
        sp.setStringList(_kSubscribed, have.toList()..sort());
    for (final t in have.difference(want)) {
      try {
        await m.unsubscribeFromTopic(t);
        have.remove(t);
        await save();
      } catch (e) {
        debugPrint('Push: unsubscribe $t failed: $e');
      }
    }
    for (final t in want.difference(have)) {
      try {
        await m.subscribeToTopic(t);
        have.add(t);
        await save();
      } catch (e) {
        debugPrint('Push: subscribe $t failed: $e');
      }
    }
  }
}
