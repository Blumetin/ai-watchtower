import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'alert.dart';
import 'demo_scenario.dart';

class AlertFeed {
  final List<Alert> alerts;
  final bool fromCache;

  final DateTime? syncedAt;

  final bool failed;
  const AlertFeed(
    this.alerts, {
    this.fromCache = false,
    this.syncedAt,
    this.failed = false,
  });

  bool get stale => fromCache || failed;

  AlertFeed asFailed() =>
      AlertFeed(alerts, fromCache: fromCache, syncedAt: syncedAt, failed: true);

  List<Alert> orderedAt(DateTime now) => [
    ...alerts.where((a) => !a.isExpiredAt(now)),
    ...alerts.where((a) => a.isExpiredAt(now)),
  ];
}

class SyncStatus {
  final DateTime? lastRunAt;
  final bool ok;
  final DateTime? lastOkAt;
  const SyncStatus({this.lastRunAt, required this.ok, this.lastOkAt});

  static DateTime? _time(Object? v) => switch (v) {
    final Timestamp t => t.toDate(),
    final DateTime d => d,
    final String s => DateTime.tryParse(s),
    _ => null,
  };

  static const overdueAfter = Duration(minutes: 25);
  bool overdueAt(DateTime now) =>
      lastRunAt != null && now.difference(lastRunAt!) > overdueAfter;

  factory SyncStatus.fromMap(Map<String, dynamic> m) => SyncStatus(
    lastRunAt: _time(m['last_run_at']),
    ok: m['ok'] != false,
    lastOkAt: _time(m['last_ok_at']),
  );
}

abstract class AlertRepository {
  Stream<AlertFeed> watchActive();

  Stream<SyncStatus?> watchSyncStatus();

  Future<List<Alert>> fetchRecentlyEnded({
    Duration window = const Duration(hours: 24),
    int limit = 50,
  });
}

const _endedStatuses = {'expired', 'closed'};

const _historyPage = 200;

AlertFeed _feed(List<Alert> all, {bool fromCache = false}) {
  final synced = all.map((a) => a.syncedAt).whereType<DateTime>();
  return AlertFeed(
    _activeSorted(all),
    fromCache: fromCache,
    syncedAt: synced.isEmpty
        ? null
        : synced.reduce((a, b) => a.isAfter(b) ? a : b),
  );
}

int severityRank(String? s) => switch (s) {
  'extreme' => 0,
  'critical' => 1,
  'warning' => 2,
  'info' => 3,
  _ => 4,
};

int compareAlerts(Alert a, Alert b) {
  final r = severityRank(a.severity).compareTo(severityRank(b.severity));
  if (r != 0) return r;
  return (b.updated ?? DateTime(0)).compareTo(a.updated ?? DateTime(0));
}

List<Alert> _activeSorted(Iterable<Alert> alerts) =>
    alerts.where((a) => a.status == 'active').toList()..sort(compareAlerts);

class FirestoreAlertRepository implements AlertRepository {
  final FirebaseFirestore _db;
  FirestoreAlertRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  @override
  Stream<AlertFeed> watchActive() {
    final base = _db
        .collection('alerts')
        .snapshots(includeMetadataChanges: true);
    List<Alert> active(QuerySnapshot<Map<String, dynamic>> snap) => [
      for (final d in snap.docs)
        Alert.fromMap({
          ...d.data(),
          if (d.data()['synced_at'] case final Timestamp ts)
            'synced_at': ts.toDate(),
        }),
    ];
    if (!demoScenarioEnabled) {
      return base.map(
        (snap) => _feed(active(snap), fromCache: snap.metadata.isFromCache),
      );
    }
    final scenario = _scenarioAlert(_db, demoScenarioUid);
    return base.asyncMap((snap) async {
      final extra = await scenario;
      return _feed([
        ...active(snap),
        if (extra != null && !snap.docs.any((d) => d.id == demoScenarioUid))
          extra,
      ], fromCache: snap.metadata.isFromCache);
    });
  }

  @override
  Stream<SyncStatus?> watchSyncStatus() async* {
    try {
      await for (final d in _db.doc('meta/sync_status').snapshots()) {
        yield d.exists ? SyncStatus.fromMap(d.data()!) : null;
      }
    } catch (_) {
      yield null;
    }
  }

  @override
  Future<List<Alert>> fetchRecentlyEnded({
    Duration window = const Duration(hours: 24),
    int limit = 50,
  }) async {
    final query = _db
        .collection('history')
        .where(
          'ended_at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime.now().subtract(window),
          ),
        )
        .orderBy('ended_at', descending: true)
        .limit(_historyPage);
    final out = <Alert>[];
    DocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      final snap = await (last == null ? query : query.startAfterDocument(last))
          .get(const GetOptions(source: Source.server));
      for (final d in snap.docs) {
        if (_endedStatuses.contains(d.data()['status'])) {
          out.add(
            Alert.fromMap({
              ...d.data(),
              for (final k in const ['synced_at', 'ended_at'])
                if (d.data()[k] case final Timestamp ts) k: ts.toDate(),
            }),
          );
        }
      }
      if (out.length >= limit || snap.docs.length < _historyPage) break;
      last = snap.docs.last;
    }
    return out.take(limit).toList();
  }
}

class RestAlertRepository implements AlertRepository {
  static const _base =
      'https://firestore.googleapis.com/v1/projects/ai-watchtower-tw/databases/(default)/documents/alerts';

  final http.Client _client;
  final Duration interval;
  RestAlertRepository({
    http.Client? client,
    this.interval = const Duration(minutes: 2),
  }) : _client = client ?? http.Client();

  @override
  Stream<AlertFeed> watchActive() {
    late final StreamController<AlertFeed> controller;
    Timer? timer;
    var cancelled = false;
    var inFlight = false;
    Future<void> tick() async {
      if (inFlight || cancelled) return;
      inFlight = true;
      try {
        final feed = await _fetch();
        if (!cancelled) controller.add(feed);
      } catch (e, st) {
        if (!cancelled) controller.addError(e, st);
      } finally {
        inFlight = false;
      }
    }

    controller = StreamController<AlertFeed>(
      onListen: () {
        tick();
        timer = Timer.periodic(interval, (_) => tick());
      },
      onCancel: () {
        cancelled = true;
        timer?.cancel();
      },
    );
    return controller.stream;
  }

  SyncStatus? _lastSync;

  @override
  Stream<SyncStatus?> watchSyncStatus() {
    late final StreamController<SyncStatus?> controller;
    Timer? timer;
    var cancelled = false;
    var inFlight = false;
    Future<void> tick() async {
      if (inFlight || cancelled) return;
      inFlight = true;
      try {
        final res = await _client
            .get(
              Uri.parse(
                'https://firestore.googleapis.com/v1/projects/ai-watchtower-tw/databases/(default)/documents/meta/sync_status',
              ),
            )
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 && !cancelled) {
          final body =
              jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          final next = SyncStatus.fromMap(
            decodeFields(body['fields'] as Map<String, dynamic>? ?? {}),
          );
          final prev = _lastSync?.lastRunAt;
          if (prev == null ||
              (next.lastRunAt != null && !next.lastRunAt!.isBefore(prev))) {
            _lastSync = next;
          }
        } else if (kDebugMode && res.statusCode != 403) {
          debugPrint('sync_status HTTP ${res.statusCode}');
        }
      } catch (_) {
      } finally {
        inFlight = false;
      }
      if (!cancelled) controller.add(_lastSync);
    }

    controller = StreamController<SyncStatus?>(
      onListen: () {
        tick();
        timer = Timer.periodic(interval, (_) => tick());
      },
      onCancel: () {
        cancelled = true;
        timer?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<List<Alert>> fetchRecentlyEnded({
    Duration window = const Duration(hours: 24),
    int limit = 50,
  }) async {
    final since = DateTime.now().toUtc().subtract(window).toIso8601String();
    final out = <Alert>[];
    for (var offset = 0; ; offset += _historyPage) {
      final rows = await _runHistoryQuery(since, offset);
      for (final row in rows) {
        if (row['document']?['fields'] case final Map<String, dynamic> f) {
          final fields = decodeFields(f);
          if (_endedStatuses.contains(fields['status'])) {
            out.add(Alert.fromMap(fields));
          }
        }
      }
      final docs = rows.where((r) => r['document'] != null).length;
      if (out.length >= limit || docs < _historyPage) break;
    }
    return out.take(limit).toList();
  }

  Future<List<dynamic>> _runHistoryQuery(String since, int offset) async {
    final res = await _client
        .post(
          Uri.parse(
            'https://firestore.googleapis.com/v1/projects/ai-watchtower-tw/databases/(default)/documents:runQuery',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'structuredQuery': {
              'from': [
                {'collectionId': 'history'},
              ],
              'where': {
                'fieldFilter': {
                  'field': {'fieldPath': 'ended_at'},
                  'op': 'GREATER_THAN_OR_EQUAL',
                  'value': {'timestampValue': since},
                },
              },
              'orderBy': [
                {
                  'field': {'fieldPath': 'ended_at'},
                  'direction': 'DESCENDING',
                },
              ],
              'offset': offset,
              'limit': _historyPage,
            },
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Firestore REST ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as List;
  }

  Future<AlertFeed> _fetch() async {
    final alerts = <Alert>[];
    String? pageToken;
    do {
      final uri = Uri.parse(
        _base,
      ).replace(queryParameters: {'pageSize': '300', 'pageToken': ?pageToken});
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw Exception('Firestore REST ${res.statusCode}');
      }
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      for (final doc in (body['documents'] as List? ?? [])) {
        alerts.add(
          Alert.fromMap(
            decodeFields(doc['fields'] as Map<String, dynamic>? ?? {}),
          ),
        );
      }
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null);
    return _feed(alerts);
  }
  
  static Map<String, dynamic> decodeFields(Map<String, dynamic> fields) =>
      fields.map(
        (k, v) => MapEntry(k, _decodeValue(v as Map<String, dynamic>)),
      );

  static dynamic _decodeValue(Map<String, dynamic> typed) {
    if (typed.containsKey('nullValue')) return null;
    if (typed['arrayValue'] case final Map<String, dynamic> arr) {
      return [
        for (final v in (arr['values'] as List? ?? []))
          _decodeValue(v as Map<String, dynamic>),
      ];
    }
    if (typed['mapValue'] case final Map<String, dynamic> map) {
      return decodeFields(map['fields'] as Map<String, dynamic>? ?? {});
    }
    if (typed['integerValue'] case final String i) return int.parse(i);
    return typed.values.first;
  }
}



class UnavailableAlertRepository implements AlertRepository {
  const UnavailableAlertRepository();

  @override
  Stream<AlertFeed> watchActive() =>
      Stream.error(StateError('Firebase unavailable'));

  @override
  Stream<SyncStatus?> watchSyncStatus() => Stream.value(null);

  @override
  Future<List<Alert>> fetchRecentlyEnded({
    Duration window = const Duration(hours: 24),
    int limit = 50,
  }) => Future.error(StateError('Firebase unavailable'));
}



final alertUidPattern = RegExp(r'^[A-Za-z0-9_.#-]{1,200}$');



Future<Alert?> fetchAlertByUid(String uid) async {
  if (!alertUidPattern.hasMatch(uid)) return null;
  final db = FirebaseFirestore.instance;
  var d = await db.doc('alerts/$uid').get();
  if (!d.exists) {
    if (demoScenarioEnabled && uid == demoScenarioUid) {
      return _scenarioAlert(db, uid);
    }
    d = await db.doc('history/$uid').get();
  }
  final m = d.data();
  if (m == null) return null;
  return Alert.fromMap({
    ...m,
    for (final k in const ['synced_at', 'ended_at'])
      if (m[k] case final Timestamp ts) k: ts.toDate(),
  });
}



Future<Alert?> _scenarioAlert(FirebaseFirestore db, String uid) async {
  if (!demoScenarioEnabled || !alertUidPattern.hasMatch(uid)) return null;
  try {
    final m = (await db.doc('history/$uid').get()).data();
    if (m == null) return null;
    return Alert.fromMap(
      asScenarioActive({
        ...m,
        for (final k in const ['synced_at', 'ended_at'])
          if (m[k] case final Timestamp ts) k: ts.toDate(),
      }),
    );
  } catch (e) {
    debugPrint('demo scenario load failed: $e');
    return null;
  }
}
