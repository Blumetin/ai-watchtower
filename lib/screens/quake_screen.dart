import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:material_symbols_icons/symbols.dart';

import '../data/alert_repository.dart' show SyncStatus;
import '../data/app_check_keeper.dart';
import '../data/earthquake.dart';
import '../data/push_prefs.dart' show countyNameFromZh;
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../web/site_chrome.dart' show sitePage;
import '../web/web_restore.dart';
import '../widgets/app_map.dart';
import '../widgets/call.dart';
import '../widgets/restore_state.dart';
import '../widgets/time_format.dart';

class QuakeScreen extends StatelessWidget {
  final EarthquakeRepository repository;

  final void Function(Earthquake quake, bool isSample)? onOpen;
  const QuakeScreen({super.key, required this.repository, this.onOpen});

  static const _tabStorageId = 'quake-sub-tab';
  static const _restoreTabId = 'quake.tab';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final storage = PageStorage.maybeOf(context);
    final restored = RestoreTabSaver.take(_restoreTabId, 2);
    if (restored != null) {
      storage?.writeState(context, restored, identifier: _tabStorageId);
    }
    final saved = storage?.readState(context, identifier: _tabStorageId);
    final lastTab =
        restored ?? (saved is int && saved >= 0 && saved < 2 ? saved : 0);
    return DefaultTabController(
      length: 2,
      initialIndex: lastTab,
      child: RestoreTabSaver(
        id: _restoreTabId,
        child: Column(
          children: [
            Material(
              color: Colors.white,
              child: TabBar(
                onTap: (i) =>
                    storage?.writeState(context, i, identifier: _tabStorageId),
                labelStyle: Theme.of(context).textTheme.titleMedium,
                tabs: [
                  Tab(height: AppLayout.touchTarget, text: t.recentQuakes),
                  Tab(height: AppLayout.touchTarget, text: t.historyMap),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _RecentList(repository: repository, onOpen: onOpen),
                  const HistoryMap(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentList extends StatefulWidget {
  final EarthquakeRepository repository;
  final void Function(Earthquake quake, bool isSample)? onOpen;
  const _RecentList({required this.repository, this.onOpen});

  @override
  State<_RecentList> createState() => _RecentListState();
}

class _RecentListState extends State<_RecentList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Earthquake>? _quakes;
  SyncStatus? _status;
  bool _failed = false;
  Future<void>? _inFlight;
  Timer? _timer;

  final _scroll = ScrollController();
  late final RestoreScroll _restore;

  @override
  void initState() {
    super.initState();
    _restore = RestoreScroll('quake.recent', _scroll);
    _load(force: true);
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _load());
    AppCheckKeeper.reconnected.addListener(_onReconnected);
  }

  void _onReconnected() {
    final running = _inFlight;
    if (running == null) {
      _load(force: true);
    } else {
      running.whenComplete(() {
        if (mounted) _load(force: true);
      });
    }
  }

  @override
  void dispose() {
    AppCheckKeeper.reconnected.removeListener(_onReconnected);
    _timer?.cancel();
    _restore.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool _inFlightForced = false;

  Future<void>? _forcedNext;

  Future<void> _load({bool force = false}) {
    if (!mounted) return Future.value();
    final running = _inFlight;
    if (running != null) {
      if (!force || _inFlightForced) return running;
      return _forcedNext ??= running.then((_) async {
        _forcedNext = null;
        if (mounted) await _load(force: true);
      });
    }
    _inFlightForced = force;
    return _inFlight = _doLoad(force).whenComplete(() {
      _inFlight = null;
      _inFlightForced = false;
    });
  }

  Future<void> _doLoad(bool force) async {
    if (_failed && mounted) setState(() => _failed = false);
    try {
      final status = await widget.repository.fetchStatus().catchError(
        (_) => null,
      );
      if (!mounted) return;
      final prev = _status;
      final unchanged =
          !force &&
          _quakes != null &&
          !widget.repository.recentFromCache &&
          status != null &&
          prev != null &&
          status.lastRunAt != null &&
          status.lastRunAt == prev.lastRunAt;
      final quakes = unchanged
          ? _quakes!
          : await widget.repository.fetchRecent();
      if (!mounted) return;
      setState(() {
        _quakes = quakes;
        _status = status ?? _status;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final quakes = _quakes;
    if (quakes == null) {
      return _failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.loadFailed, style: text.bodyMedium),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _load(force: true),
                    child: Text(t.retry),
                  ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator());
    }
    final status = _status;
    if (!widget.repository.recentFromCache) _restore.apply();
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: _list(context, t, text, locale, quakes, status),
    );
  }

  Widget _list(
    BuildContext context,
    AppLocalizations t,
    TextTheme text,
    String locale,
    List<Earthquake> quakes,
    SyncStatus? status,
  ) {
    final muted = text.labelMedium!.copyWith(color: AppColors.textMuted);
    final overdue = status?.overdueAt(DateTime.now()) ?? false;
    return ListView(
      controller: kIsWeb ? _scroll : null,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppLayout.pagePadding,
      children: [
        if (status != null) ...[
          Text(
            status.ok
                ? (overdue
                      ? t.syncOverdue(absoluteTime(locale, status.lastRunAt))
                      : t.lastSynced(absoluteTime(locale, status.lastRunAt)))
                : status.lastOkAt == null
                ? t.syncFailedNever
                : t.syncFailedSince(absoluteTime(locale, status.lastOkAt)),
            style: status.ok && !overdue
                ? muted
                : text.labelMedium!.copyWith(color: AppColors.attention),
          ),
          const SizedBox(height: 8),
        ],
        if (widget.repository.recentFromCache) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              t.staleData,
              style: text.labelMedium!.copyWith(color: AppColors.attention),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_failed) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              t.updateFailed,
              style: text.bodySmall!.copyWith(color: AppColors.attention),
            ),
          ),
          const SizedBox(height: 8),
        ],
        ..._items(context, t, text, quakes),
      ],
    );
  }

  List<Widget> _items(
    BuildContext context,
    AppLocalizations t,
    TextTheme text,
    List<Earthquake> quakes,
  ) {
    return [
      if (widget.repository.isSample) ...[
        Text(
          t.sampleDataNotice,
          style: text.bodySmall!.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppLayout.gap),
      ],
      if (quakes.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(t.quakeReportDelay, style: text.bodyMedium),
        ),
      for (final q in quakes)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: QuakeCard(
            quake: q,
            onTap: () => widget.onOpen != null
                ? widget.onOpen!(q, widget.repository.isSample)
                : Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuakeDetailScreen(
                        quake: q,
                        isSample: widget.repository.isSample,
                      ),
                    ),
                  ),
          ),
        ),
      if (quakes.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          t.quakeReportDelay,
          style: text.bodySmall!.copyWith(color: AppColors.textMuted),
        ),
      ],
      const SizedBox(height: 16),
      CwaAttribution(
        dataset: t.datasetQuakes,
        datasetId:
            '${CwaAttribution.datasetSignificantId} / ${CwaAttribution.datasetLocalId}',
        year: CwaAttribution.yearsOf(quakes.map((q) => q.originTime)),
      ),
    ];
  }
}


class CwaAttribution extends StatelessWidget {
  final String dataset;
  final String datasetId;

  final String? year;
  const CwaAttribution({
    super.key,
    required this.dataset,
    required this.datasetId,
    this.year,
  });

  static const datasetSignificantId = 'E-A0015-001';
  static const datasetLocalId = 'E-A0016-001';
  static const licenseUrl = 'https://data.gov.tw/license';

  static String? yearsOf(Iterable<DateTime?> times) {
    final years = times.whereType<DateTime>().map((d) => d.year).toSet();
    if (years.isEmpty) return null;
    final lo = years.reduce((a, b) => a < b ? a : b);
    final hi = years.reduce((a, b) => a > b ? a : b);
    return lo == hi ? '$lo' : '$lo–$hi';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          year == null
              ? t.cwaAttributionNoYear(dataset, datasetId)
              : t.cwaAttribution(year!, dataset, datasetId),
          style: text.labelMedium!.copyWith(color: AppColors.textMuted),
        ),
        TextButton.icon(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.centerLeft,
            minimumSize: const Size(0, AppLayout.touchTarget),
          ),
          onPressed: () => openExternal(context, licenseUrl),
          icon: const Icon(Symbols.open_in_new_rounded, size: 18),
          label: Text(t.openDataLicense),
        ),
      ],
    );
  }
}

class QuakeCard extends StatelessWidget {
  final Earthquake quake;
  final VoidCallback onTap;
  const QuakeCard({super.key, required this.quake, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final color = intensityColor(quake.maxIntensity);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radius),
        side: const BorderSide(
          color: AppColors.cardBorder,
          width: AppLayout.borderWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: MergeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  constraints: BoxConstraints(
                    minWidth: quake.isLocal ? 52 : 64,
                    minHeight: quake.isLocal ? 52 : 64,
                    maxWidth: 120,
                  ),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppLayout.radius),
                  ),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Text(
                      intensityLabel(lang, quake.maxIntensity),
                      textAlign: TextAlign.center,
                      style: text.titleMedium!.copyWith(
                        color: onIntensityColor(quake.maxIntensity),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'M ${quake.magnitude.toStringAsFixed(1)}',
                            style: text.headlineSmall,
                          ),
                          if (quake.isLocal) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.outline),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                t.localQuake,
                                style: text.labelMedium,
                              ),
                            ),
                          ],
                          Text(
                            relativeTime(t, quake.originTime),
                            style: text.labelMedium!.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (quake.locationFor(lang) == null)
                        Text(
                          t.originalText,
                          style: text.labelMedium!.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      Text(
                        quake.locationFor(lang) ?? quake.location,
                        style: text.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.depth} ${t.depthKm(quake.depthKm.toStringAsFixed(1))}',
                        style: text.labelMedium!.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


const _taiwanMainIsland = [MapPoint(21.9, 120.0), MapPoint(25.3, 122.0)];

class QuakeDetailScreen extends StatelessWidget {
  final Earthquake quake;

  
  final bool isSample;

  
  final bool embedded;
  const QuakeDetailScreen({
    super.key,
    required this.quake,
    this.isSample = false,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final epicenter = MapPoint(quake.lat, quake.lon);
    final level = intensityLabel(lang, quake.maxIntensity);
    
    Widget map(double width, double height) => Align(
      alignment: AlignmentDirectional.topStart,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.radiusLg),
        child: SizedBox(
          width: width,
          height: height,
          child: AppMap(
            center: epicenter,
            zoom: 8,
            fit: [..._taiwanMainIsland, epicenter],
            fitPadding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            fitMaxZoom: 9,
            crosses: [epicenter],
            crossColor: AppColors.primary,
            simpleGestures: true,
          ),
        ),
      ),
    );
    
    final header = <Widget>[
      Text(
        'M ${quake.magnitude.toStringAsFixed(1)}',
        style: text.headlineLarge,
      ),
      const SizedBox(height: 4),
      Text(
        quake.maxIntensityCounties.isEmpty
            ? '${t.maxIntensity} $level'
            : t.maxIntensityIn(
                level,
                quake.maxIntensityCounties
                    .map((c) => countyNameFromZh(c, lang))
                    .join(lang == 'zh' || lang == 'ja' ? '、' : ', '),
              ),
        style: text.titleMedium,
      ),
    ];

    final info = <Widget>[
      _Row(t.originTime, absoluteTime(lang, quake.originTime)),
      _Row(
        t.epicenter,
        '${quake.locationFor(lang) ?? t.withLabel(quake.location, t.originalText)}\n${quake.lat.toStringAsFixed(2)}°N, ${quake.lon.toStringAsFixed(2)}°E',
      ),
      _Row(t.depth, t.depthKm(quake.depthKm.toStringAsFixed(1))),
      
      const SizedBox(height: AppLayout.gap),
      Text(
        t.quakeSourceLine,
        style: text.bodySmall!.copyWith(color: AppColors.onSurfaceVariant),
      ),
      if (quake.reportUrl.isNotEmpty) ...[
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, AppLayout.touchTarget),
            ),
            onPressed: () => openExternal(context, quake.reportUrl),
            icon: const Icon(Symbols.open_in_new_rounded, size: 18),
            label: Text(t.reportLink),
          ),
        ),
      ],
    ];

    final sampleNotice = [
      if (isSample) ...[
        Text(
          t.sampleDataNotice,
          style: text.bodySmall!.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
      ],
    ];

    return sitePage(
      embedded: embedded,
      title: t.quakeDetail,
      
      body: LayoutBuilder(
        builder: (context, c) {
          
          final landscape = _appLayout(context) && c.maxWidth > c.maxHeight;
          
          final safe = MediaQuery.paddingOf(context);
          
          final minMapH = MediaQuery.sizeOf(context).shortestSide < 600
              ? 120.0
              : 200.0;
          
          final mapH = (c.maxHeight - 32 - safe.bottom).clamp(minMapH, 520.0);
          final mapW = mapH * 1.25;
          
          final infoW =
              c.maxWidth -
              safe.left -
              safe.right -
              AppLayout.pagePadding.horizontal -
              mapW -
              AppLayout.gap;
          
          final sideBySide =
              landscape &&
              c.maxHeight - 32 - safe.bottom >= minMapH &&
              infoW >= 280 * MediaQuery.textScalerOf(context).scale(16) / 16;
          
          final padding = landscape
              ? AppLayout.pagePadding.copyWith(
                  top: 8,
                  left: AppLayout.pagePadding.left + safe.left,
                  right: AppLayout.pagePadding.right + safe.right,
                  bottom: AppLayout.pagePadding.bottom + safe.bottom,
                )
              : AppLayout.pagePadding;

          if (sideBySide) {
            return Padding(
              padding: padding.copyWith(top: 16, bottom: 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    container: true,
                    sortKey: const OrdinalSortKey(2),
                    child: map(mapW, mapH),
                  ),
                  const SizedBox(width: AppLayout.gap),
                  Expanded(
                    child: Semantics(
                      container: true,
                      sortKey: const OrdinalSortKey(1),
                      child: ListView(
                        padding: EdgeInsets.only(
                          top: 6,
                          bottom: padding.bottom,
                        ),
                        children: [
                          ...sampleNotice,
                          ...header,
                          const SizedBox(height: AppLayout.gap),
                          ...info,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          
          const scrollMapH = 200.0;
          const scrollMapW = scrollMapH * 1.25;
          final scrollInfoW =
              c.maxWidth -
              safe.left -
              safe.right -
              AppLayout.pagePadding.horizontal -
              scrollMapW -
              AppLayout.gap;
          if (landscape &&
              MediaQuery.sizeOf(context).shortestSide < 600 &&
              scrollInfoW >=
                  280 * MediaQuery.textScalerOf(context).scale(16) / 16) {
            return SingleChildScrollView(
              padding: padding.copyWith(top: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    container: true,
                    sortKey: const OrdinalSortKey(2),
                    child: map(scrollMapW, scrollMapH),
                  ),
                  const SizedBox(width: AppLayout.gap),
                  Expanded(
                    child: Semantics(
                      container: true,
                      sortKey: const OrdinalSortKey(1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 6),
                          ...sampleNotice,
                          ...header,
                          const SizedBox(height: AppLayout.gap),
                          ...info,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: padding,
            children: [
              ...sampleNotice,
              ...header,
              const SizedBox(height: AppLayout.gap),
              LayoutBuilder(
                builder: (context, c) {
                  final screenH = MediaQuery.sizeOf(context).height;
                  final double height = (c.maxWidth * 1.05).clamp(
                    260.0,
                    math.max(260.0, screenH * 0.55),
                  );
                  return map(math.min(c.maxWidth, height * 1.25), height);
                },
              ),
              const SizedBox(height: AppLayout.gap),
              ...info,
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder,
            width: AppLayout.borderWidth,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: text.labelMedium!.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(child: Text(value, style: text.bodySmall)),
        ],
      ),
    );
  }
}


class HistoryMap extends StatefulWidget {
  const HistoryMap({super.key});

  @override
  State<HistoryMap> createState() => _HistoryMapState();
}

class _HistoryMapState extends State<HistoryMap>
    with AutomaticKeepAliveClientMixin {
  
  
  late Future<List<HistoricalQuake>> _future = _load();
  static Future<List<HistoricalQuake>> _load() async =>
      (await loadHistoricalQuakes())..sort((a, b) => b.mag.compareTo(a.mag));
  static final _magSteps = [for (var i = 45; i <= 77; i++) i / 10];
  final _mapKey = GlobalKey();
  static const _compactFit = [MapPoint(21.8, 119.6), MapPoint(25.4, 122.4)];

  
  MapPoint _center = const MapPoint(23.7, 121.0);
  double _zoom = 6.5;

  
  MapPoint? _camCenter;
  double? _camZoom;

  static const _restoreId = 'quake.history';
  late final Object? Function() _saver = _save;
  Object? _save() => {
    'mag': _minMag,
    if (_camCenter != null && _camZoom != null)
      'cam': [_camCenter!.lat, _camCenter!.lon, _camZoom],
  };

  @override
  void initState() {
    super.initState();
    final r = WebRestore.take(_restoreId);
    if (r is Map) {
      final mag = r['mag'], cam = r['cam'];
      if (mag is num && _magSteps.contains(mag.toDouble())) {
        _minMag = _mapMag = mag.toDouble();
      }
      if (cam is List && cam.length == 3 && cam.every((v) => v is num)) {
        final lat = (cam[0] as num).toDouble(),
            lon = (cam[1] as num).toDouble();
        final zoom = (cam[2] as num).toDouble();
        if (lat.abs() <= 85 && lon.abs() <= 180 && zoom >= 5 && zoom <= 12) {
          _center = _camCenter = MapPoint(lat, lon);
          _zoom = _camZoom = zoom;
        }
      }
    }
    WebRestore.register(_restoreId, _saver);
  }

  
  
  FixedExtentScrollController? _magController;
  Object? _magLayout;
  FixedExtentScrollController _magControllerFor(Object layout) {
    if (_magController == null || _magLayout != layout) {
      final old = _magController;
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
      _magController = FixedExtentScrollController(
        initialItem: math.max(0, _magSteps.indexOf(_minMag)),
      );
      _magLayout = layout;
    }
    return _magController!;
  }

  
  double _minMag = 4.5;

  
  double _mapMag = 4.5;
  static const _mapDelay = Duration(milliseconds: 300);
  Timer? _mapTimer;

  
  List<MapCircle>? _circles;
  double? _circlesMag;

  @override
  void dispose() {
    WebRestore.unregister(_restoreId, _saver);
    _mapTimer?.cancel();
    _magController?.dispose();
    super.dispose();
  }

  void _onMagChanged(double m) {
    setState(() => _minMag = m);
    _mapTimer?.cancel();
    _mapTimer = Timer(_mapDelay, () {
      if (mounted) setState(() => _mapMag = _minMag);
    });
  }

  List<MapCircle> _circlesFor(List<HistoricalQuake> all) {
    if (_circles != null && _circlesMag == _mapMag) return _circles!;
    _circlesMag = _mapMag;
    return _circles = [
      for (final q in all.takeWhile((q) => q.mag >= _mapMag))
        MapCircle(
          MapPoint(q.lat, q.lon),
          2.5 + (q.mag - 4.5) * 3,
          _depthColor(q.depthKm).withValues(alpha: 0.45),
          _depthColor(q.depthKm),
        ),
    ];
  }

  @override
  bool get wantKeepAlive => true;

  
  static double _legendHeight(
    BuildContext context,
    List<String> labels,
    TextStyle style,
    double width,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    double total = 0, lineW = 0, lineH = 0;
    for (final label in labels) {
      final tp = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: dir,
        textScaler: scaler,
      )..layout(maxWidth: math.max(1, width - 18));
      final w = 18 + tp.width;
      final h = math.max(12.0, tp.height);
      tp.dispose();
      if (lineW > 0 && lineW + 16 + w > width) {
        total += lineH + 4;
        lineW = 0;
        lineH = 0;
      }
      lineW = lineW == 0 ? w : lineW + 16 + w;
      lineH = math.max(lineH, h);
    }
    return total + lineH + 16;
  }

  
  static ({double width, double height}) _oneLineLegend(
    BuildContext context,
    List<String> parts,
    TextStyle style,
  ) {
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    double width = 0, height = 0;
    for (final (i, part) in parts.indexed) {
      final tp = TextPainter(
        text: TextSpan(text: part, style: style),
        textDirection: dir,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      
      width += (i == 0 ? 0 : 10 + 10 + 4) + tp.width;
      height = math.max(height, tp.height);
      tp.dispose();
    }
    return (width: width, height: height);
  }

  static Color _depthColor(double km) => km < 30
      ? AppColors.scaleRed
      : km <= 70
      ? AppColors.secondaryContainer
      : AppColors.tertiary;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.historyLoadFailed, style: text.bodyMedium),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() {
                    _circles = null;
                    _circlesMag = null;
                    _future = _load();
                  }),
                  child: Text(t.retry),
                ),
              ],
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final shown = snap.data!.takeWhile((q) => q.mag >= _minMag).length;
        
        Widget caption({bool large = false}) => Text(
          t.historyCaption(snap.data!.length),
          style: large ? text.bodyMedium : text.bodySmall,
        );
        
        Widget picker({
          required bool wide,
          required bool panel,
          double height = 96,
        }) {
          
          final scale =
              MediaQuery.textScalerOf(context).scale(16).clamp(16.0, 32.0) / 16;
          final extent = (wide ? 48.0 : 36.0) * scale;
          final layout = (panel, wide, extent);
          
          return MediaQuery.withClampedTextScaling(
            maxScaleFactor: 2,
            child: SizedBox(
              width: (wide ? 120.0 : 88.0) * scale,
              height: math.max(height, extent * 2.5),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: CupertinoPicker(
                  key: ValueKey(layout),
                  itemExtent: extent,
                  magnification: 1.15,
                  useMagnifier: true,
                  scrollController: _magControllerFor(layout),
                  onSelectedItemChanged: (i) => _onMagChanged(_magSteps[i]),
                  children: [
                    for (final m in _magSteps)
                      Center(
                        child: Text(
                          m.toStringAsFixed(1),
                          style: wide
                              ? text.headlineMedium
                              : text.headlineSmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }

        final shownText = Text(
          t.shownCount(shown),
          style: text.labelMedium!.copyWith(color: AppColors.textMuted),
        );
        Widget legendItem(String label, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 6, backgroundColor: color),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: text.labelMedium)),
          ],
        );
        final legendItems = [
          legendItem(t.shallow, AppColors.scaleRed),
          legendItem(t.intermediate, AppColors.secondaryContainer),
          legendItem(t.deep, AppColors.tertiary),
        ];
        
        Widget mapFor({bool compact = false, double fitTop = 8}) => AppMap(
          key: _mapKey,
          center: _center,
          zoom: _zoom,
          minZoom: 5,
          maxZoom: 12,
          fit: compact ? _compactFit : null,
          
          fitPadding: EdgeInsets.fromLTRB(8, fitTop, 8, 8),
          
          simpleGestures: true,
          circles: _circlesFor(snap.data!),
          
          onCameraMove: kIsWeb
              ? (c, z) {
                  _camCenter = c;
                  _camZoom = z;
                }
              : null,
        );
        return LayoutBuilder(
          builder: (context, c) {
            if (_appLayout(context) && c.maxWidth > c.maxHeight) {
              final safe = MediaQuery.paddingOf(context);
              final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
              final panelW = math.min(c.maxWidth * 0.4, 360 * scale);
              final compact = c.maxHeight < 360;
              final mapAreaW = c.maxWidth - panelW - safe.left - safe.right;
              final oneLine = _oneLineLegend(context, [
                t.historyDepthKm,
                '< 30',
                '30–70',
                '> 70',
              ], text.bodySmall!);
              final overlayLegend =
                  compact && oneLine.width <= mapAreaW - 16 - 16;
              final lang = Localizations.localeOf(context).languageCode;
              final wheelH = (c.maxHeight * 0.32).clamp(132.0, 240.0);
              Widget dot(Color color, String label) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 5, backgroundColor: color),
                  const SizedBox(width: 4),
                  Text(label, style: text.bodySmall),
                ],
              );
              final legendCard = Semantics(
                label: [
                  t.shallow,
                  t.intermediate,
                  t.deep,
                ].join(lang == 'zh' || lang == 'ja' ? '、' : ', '),
                excludeSemantics: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(AppLayout.radiusLg),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(t.historyDepthKm, style: text.bodySmall),
                        dot(AppColors.scaleRed, '< 30'),
                        dot(AppColors.secondaryContainer, '30–70'),
                        dot(AppColors.tertiary, '> 70'),
                      ],
                    ),
                  ),
                ),
              );
              final panelChildren = compact
                  ? <Widget>[
                      Semantics(
                        container: true,
                        sortKey: const OrdinalSortKey(2),
                        child: SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Text(t.magnitude, style: text.titleMedium),
                              picker(wide: false, panel: true, height: 90),
                              Text(t.atLeast, style: text.titleMedium),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Semantics(
                        container: true,
                        sortKey: const OrdinalSortKey(3),
                        child: shownText,
                      ),
                      const SizedBox(height: 8),
                      Semantics(
                        container: true,
                        sortKey: const OrdinalSortKey(1),
                        child: caption(),
                      ),
                      const Spacer(),
                      if (!overlayLegend) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          container: true,
                          sortKey: const OrdinalSortKey(4),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 10,
                            children: legendItems,
                          ),
                        ),
                      ],
                    ]
                  : <Widget>[
                      caption(large: true),
                      const SizedBox(height: 16),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(t.magnitude, style: text.titleMedium),
                            picker(wide: true, panel: true, height: wheelH),
                            Text(t.atLeast, style: text.titleMedium),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(child: shownText),
                      const SizedBox(height: 16),
                      const Spacer(flex: 2),
                      Wrap(spacing: 16, runSpacing: 10, children: legendItems),
                    ];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: panelW + safe.left,
                    child: CustomScrollView(
                      physics: const ClampingScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            AppLayout.pageMargin + safe.left,
                            compact ? 8 : 12,
                            AppLayout.pageMargin,
                            (compact ? 8 : 16) + safe.bottom,
                          ),
                          sliver: SliverFillRemaining(
                            hasScrollBody: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: panelChildren,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: safe.right,
                        bottom: safe.bottom,
                      ),
                      child: overlayLegend
                          ? Stack(
                              children: [
                                Positioned.fill(
                                  child: Semantics(
                                    sortKey: const OrdinalSortKey(2),
                                    child: mapFor(
                                      compact: true,
                                      fitTop: 20 + oneLine.height,
                                    ),
                                  ),
                                ),
                                PositionedDirectional(
                                  start: 8,
                                  end: 8,
                                  top: 8,
                                  child: Semantics(
                                    sortKey: const OrdinalSortKey(1),
                                    child: Align(
                                      alignment: AlignmentDirectional.topStart,
                                      child: legendCard,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : mapFor(compact: compact),
                    ),
                  ),
                ],
              );
            }
            final wheelH = !_appLayout(context)
                ? 96.0
                : (c.maxHeight * 0.16).clamp(96.0, 180.0);
            final bigWheel = wheelH >= 150;
            final legendH = _legendHeight(
              context,
              [t.shallow, t.intermediate, t.deep],
              text.labelMedium!,
              c.maxWidth - 2 * AppLayout.pageMargin,
            );
            return CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppLayout.pageMargin,
                      12,
                      AppLayout.pageMargin,
                      8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        caption(),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              Text(t.magnitude, style: text.titleMedium),
                              picker(
                                wide: bigWheel,
                                panel: false,
                                height: wheelH,
                              ),
                              Text(t.atLeast, style: text.titleMedium),
                              shownText,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverLayoutBuilder(
                  builder: (context, sc) => SliverToBoxAdapter(
                    child: Column(
                      children: [
                        SizedBox(
                          height: math.max(
                            240.0,
                            sc.viewportMainAxisExtent -
                                sc.precedingScrollExtent -
                                legendH,
                          ),
                          child: mapFor(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppLayout.pageMargin,
                            vertical: 8,
                          ),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: legendItems,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}



bool _appLayout(BuildContext context) =>
    !kIsWeb ||
    ((defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android) &&
        MediaQuery.sizeOf(context).shortestSide < 600);
