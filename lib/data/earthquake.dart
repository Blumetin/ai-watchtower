import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'alert_repository.dart' show RestAlertRepository, SyncStatus;

class Earthquake {
  final String? id;

  final String? eqNo;

  final String reportType;
  bool get isLocal => reportType == 'local';
  final DateTime? originTime;
  final double magnitude;
  final double depthKm;
  final double lat;
  final double lon;
  final String location;

  final Map<String, String> locations;

  String? locationFor(String lang) => lang == 'zh' ? location : locations[lang];

  final String maxIntensity;
  final List<String> maxIntensityCounties;
  final String reportImage;
  final String reportUrl;

  final bool complete;

  const Earthquake({
    this.id,
    required this.eqNo,
    this.reportType = 'significant',
    required this.originTime,
    required this.magnitude,
    required this.depthKm,
    required this.lat,
    required this.lon,
    required this.location,
    this.locations = const {},
    required this.maxIntensity,
    required this.maxIntensityCounties,
    required this.reportImage,
    required this.reportUrl,
    this.complete = true,
  });

  factory Earthquake.fromMap(Map<String, dynamic> m, {String? id}) {
    String str(String k) => switch (m[k]) {
      final String s => s.trim(),
      _ => '',
    };
    double? numOf(String k) => switch (m[k]) {
      final num n when n.isFinite => n.toDouble(),
      final String s => switch (double.tryParse(s)) {
        final d? when d.isFinite => d,
        _ => null,
      },
      _ => null,
    };
    final originTime = switch (m['origin_time']) {
      final Timestamp ts => ts.toDate(),
      final DateTime d => d,
      final String s => DateTime.tryParse(s.trim()),
      _ => null,
    };
    final magnitude = numOf('magnitude');
    final depthKm = numOf('depth_km');
    final lat = numOf('lat');
    final lon = numOf('lon');
    final location = str('location');
    final eqNo = switch (m['eq_no']) {
      final num n when n.isFinite && n.toInt() > 0 => n.toInt().toString(),
      final String s when (int.tryParse(s.trim()) ?? 0) > 0 => s.trim(),
      _ => null,
    };
    return Earthquake(
      id: id,
      eqNo: eqNo,
      reportType: switch (m['report_type']) {
        final String s
            when const {
              'significant',
              'local',
            }.contains(s.trim().toLowerCase()) =>
          s.trim().toLowerCase(),
        _ => eqNo == null ? 'local' : 'significant',
      },
      originTime: originTime,
      magnitude: magnitude ?? 0,
      depthKm: depthKm ?? 0,
      lat: lat ?? 0,
      lon: lon ?? 0,
      location: location,
      locations: {
        for (final lang in const ['en', 'ja'])
          if (m['location_$lang'] case final String v when v.trim().isNotEmpty)
            lang: v.trim(),
      },
      maxIntensity: str('max_intensity'),
      maxIntensityCounties: [
        if (m['max_intensity_counties'] case final List l)
          for (final c in l)
            if (c is String && c.trim().isNotEmpty) c.trim(),
      ],
      reportImage: str('report_image'),
      reportUrl: str('report_url'),
      complete:
          originTime != null &&
          magnitude != null &&
          magnitude > 0 &&
          depthKm != null &&
          depthKm >= 0 &&
          lat != null &&
          lat.abs() <= 90 &&
          lon != null &&
          lon.abs() <= 180 &&
          lat != 0 &&
          lon != 0 &&
          location.isNotEmpty,
    );
  }
}

abstract class EarthquakeRepository {
  bool get isSample;

  Future<List<Earthquake>> fetchRecent();

  Future<SyncStatus?> fetchStatus() async => null;

  bool get recentFromCache => false;
}

List<Earthquake> _newestFirst(Iterable<Earthquake> quakes) =>
    quakes.where((q) => q.complete).toList()..sort(
      (a, b) =>
          (b.originTime ?? DateTime(0)).compareTo(a.originTime ?? DateTime(0)),
    );

class FirestoreEarthquakeRepository implements EarthquakeRepository {
  @override
  bool recentFromCache = false;

  final FirebaseFirestore _db;
  FirestoreEarthquakeRepository([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  @override
  bool get isSample => false;

  static Future<T> _serverFirst<T>(
    Future<T> Function([GetOptions?]) get, {
    bool Function(T)? usable,
  }) async {
    try {
      return await get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
    } on Exception {
      final cached = await get(const GetOptions(source: Source.cache));
      if (usable != null && !usable(cached)) rethrow;
      return cached;
    }
  }

  @override
  Future<List<Earthquake>> fetchRecent() async {
    final snap = await _serverFirst(
      _db
          .collection('earthquakes')
          .orderBy('origin_time', descending: true)
          .limit(100)
          .get,
      usable: (snap) => snap.docs.isNotEmpty,
    );
    recentFromCache = snap.metadata.isFromCache;
    return _newestFirst(
      snap.docs.map((d) => Earthquake.fromMap(d.data(), id: d.id)),
    );
  }

  @override
  Future<SyncStatus?> fetchStatus() async {
    try {
      final d = await _serverFirst(_db.doc('meta/quake_status').get);
      final m = d.data();
      return m == null ? null : SyncStatus.fromMap(m);
    } catch (_) {
      return null;
    }
  }
}

class RestEarthquakeRepository implements EarthquakeRepository {
  @override
  bool get recentFromCache => false;

  static const _base =
      'https://firestore.googleapis.com/v1/projects/ai-watchtower-tw/databases/(default)/documents';
  final http.Client _client;
  RestEarthquakeRepository({http.Client? client})
    : _client = client ?? http.Client();

  @override
  bool get isSample => false;

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await _client
        .get(Uri.parse('$_base/$path'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Firestore REST ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  @override
  Future<List<Earthquake>> fetchRecent() async {
    final body = await _get(
      'earthquakes?pageSize=100&orderBy=origin_time%20desc',
    );
    return _newestFirst([
      if (body['documents'] case final List docs)
        for (final doc in docs)
          if (doc case {'fields': final Map<String, dynamic> fields})
            Earthquake.fromMap(
              RestAlertRepository.decodeFields(fields),
              id: switch (doc['name']) {
                final String n => switch (n.split('/').last.trim()) {
                  '' => null,
                  final id => id,
                },
                _ => null,
              },
            ),
    ]);
  }

  @override
  Future<SyncStatus?> fetchStatus() async {
    try {
      return switch (await _get('meta/quake_status')) {
        {'fields': final Map<String, dynamic> f} => SyncStatus.fromMap(
          RestAlertRepository.decodeFields(f),
        ),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

class SampleEarthquakeRepository implements EarthquakeRepository {
  @override
  bool get recentFromCache => false;

  @override
  bool get isSample => true;

  @override
  Future<SyncStatus?> fetchStatus() async => null;

  @override
  Future<List<Earthquake>> fetchRecent() async => [
    Earthquake.fromMap(const {
      'eq_no': '115064',
      'origin_time': '2026-09-22T05:16:13+08:00',
      'magnitude': 4.2,
      'depth_km': 7.5,
      'lat': 23.21,
      'lon': 120.54,
      'location': '臺南市政府東北東方 43.9 公里 (位於臺南市楠西區)',
      'location_en': '43.9 km ENE of Tainan City Government (in Nanxi District, Tainan City)',
      'max_intensity': '4級',
      'max_intensity_counties': ['臺南市'],
      'report_image': '',
      'report_url': '',
    }),
  ];
}

class HistoricalQuake {
  final double lat;
  final double lon;
  final double depthKm;
  final double mag;
  final DateTime time;
  const HistoricalQuake(this.lat, this.lon, this.depthKm, this.mag, this.time);
}

Future<List<HistoricalQuake>> loadHistoricalQuakes() async {
  final raw = await rootBundle.loadString(
    'assets/data/usgs_tw_1996-2026_M4.5.json',
  );
  final features =
      (jsonDecode(raw) as Map<String, dynamic>)['features'] as List;
  return [
    for (final f in features)
      if (f['properties']?['type'] == 'earthquake')
        if (f['geometry']?['coordinates'] case [
          num lon,
          num lat,
          num depth,
          ...,
        ])
          HistoricalQuake(
            lat.toDouble(),
            lon.toDouble(),
            depth.toDouble(),
            (f['properties']['mag'] as num).toDouble(),
            DateTime.fromMillisecondsSinceEpoch(
              f['properties']['time'] as int,
              isUtc: true,
            ),
          ),
  ];
}

String intensityLabel(String lang, String raw) {
  if (raw.isEmpty) return '—';
  final level = raw.replaceAll('級', '');
  return switch (lang) {
    'en' => level.replaceAll('弱', ' Lower').replaceAll('強', ' Upper'),
    'ja' => level,
    _ => raw,
  };
}

class UnavailableEarthquakeRepository implements EarthquakeRepository {
  @override
  bool get recentFromCache => false;

  const UnavailableEarthquakeRepository();

  @override
  bool get isSample => false;

  @override
  Future<List<Earthquake>> fetchRecent() =>
      Future.error(StateError('Firebase unavailable'));

  @override
  Future<SyncStatus?> fetchStatus() async => null;
}
