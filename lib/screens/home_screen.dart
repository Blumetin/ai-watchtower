import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/alert.dart';
import '../data/alert_repository.dart';
import '../data/app_check_keeper.dart';
import '../data/push_prefs.dart' show countyName;
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../web/web_restore.dart';
import '../widgets/alert_card.dart';
import '../widgets/alert_opener.dart';
import '../widgets/alert_group.dart';
import '../widgets/restore_state.dart';
import '../widgets/stale_banner.dart';
import '../widgets/time_format.dart';

class HomeScreen extends StatefulWidget {
  final AlertRepository repository;

  final String? selectedUid;

  final Widget? footer;

  final void Function(Alert? top, ValueListenable<AlertFeed?> feed)?
  onTopChanged;

  final bool compactFilters;
  const HomeScreen({
    super.key,
    required this.repository,
    this.selectedUid,
    this.footer,
    this.onTopChanged,
    this.compactFilters = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Alert? _top;

  final _feed = ValueNotifier<AlertFeed?>(null);
  Object? _error;
  String? _group;
  String? _county;
  StreamSubscription<AlertFeed>? _sub;
  int _generation = 0;
  SyncStatus? _sync;
  final _endedRefresh = ValueNotifier<int>(0);

  final _list = ScrollController();

  static const _restoreId = 'alerts.filter';
  late final Object? Function() _saver = _save;
  Object? _save() =>
      _group == null && _county == null ? null : {'g': _group, 'c': _county};
  late final RestoreScroll _restore;

  bool _holdFilter = false;

  static bool _isMajor(Alert a) =>
      a.severity == 'extreme' ||
      (a.severity == 'critical' && a.severitySource == '官方等級');
  StreamSubscription<SyncStatus?>? _syncSub;

  Timer? _clock;

  @override
  void initState() {
    super.initState();
    final r = WebRestore.take(_restoreId);
    if (r is Map) {
      final g = r['g'], c = r['c'];
      if ((g == null || g is String) && (c == null || c is String)) {
        _group = g as String?;
        _county = c as String?;
        _holdFilter = g != null || c != null;
      }
    }
    WebRestore.register(_restoreId, _saver);
    _restore = RestoreScroll('alerts.list', _list);
    _subscribe();
    _watchSync();
    AppCheckKeeper.reconnected.addListener(_onReconnected);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    AppCheckKeeper.reconnected.removeListener(_onReconnected);
    _retryTimer?.cancel();
    _syncRetry?.cancel();
    _clock?.cancel();
    _syncSub?.cancel();
    _sub?.cancel();
    _feed.dispose();
    _endedRefresh.dispose();
    WebRestore.unregister(_restoreId, _saver);
    _restore.dispose();
    _list.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _syncRetries = 0;
    _watchSync();
    _endedRefresh.value++;
    return _subscribe().timeout(const Duration(seconds: 20), onTimeout: () {});
  }

  static const _maxAutoRetries = 3;
  int _recoverBudget = 0;
  int _handledReconnect = 0;
  Timer? _retryTimer;

  void _startRecoveryIfNew() {
    final epoch = AppCheckKeeper.reconnected.value;
    if (epoch == _handledReconnect) return;
    _handledReconnect = epoch;
    _recoverBudget = _maxAutoRetries;
    _syncRetries = 0;
  }

  void _onReconnected() {
    if (!mounted) return;
    _startRecoveryIfNew();
    _watchSync();
    if (_error != null) _retryLater(Duration.zero);
  }

  void _retryLater(Duration delay) {
    _startRecoveryIfNew();
    if (_recoverBudget <= 0) return;
    _recoverBudget--;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (mounted && _error != null) unawaited(_resubscribe());
    });
  }

  Future<void> _resubscribe() {
    _endedRefresh.value++;
    return _subscribe().timeout(const Duration(seconds: 20), onTimeout: () {});
  }

  void _watchSync() {
    _syncRetry?.cancel();
    _syncRetry = null;
    _syncSub?.cancel();
    final sub = widget.repository.watchSyncStatus().listen(
      (s) {
        if (mounted) setState(() => _sync = s);
      },
      onError: (Object e) => debugPrint('sync_status: $e'),
      onDone: () {
        if (!mounted || _syncRetries >= 3) return;
        _syncRetries++;
        _syncRetry = Timer(const Duration(seconds: 30), () {
          _syncRetry = null;
          if (mounted) _watchSync();
        });
      },
    );
    _syncSub = sub;
  }

  int _syncRetries = 0;
  Timer? _syncRetry;

  Future<void> _subscribe() async {
    final gen = ++_generation;
    final old = _sub;
    _sub = null;
    await old?.cancel();
    if (!mounted || gen != _generation) return;
    final first = Completer<void>();
    void done() => first.isCompleted ? null : first.complete();
    _sub = widget.repository.watchActive().listen(
      (feed) {
        if (!feed.fromCache) {
          done();
          _recoverBudget = 0;
        }
        if (mounted && gen == _generation) {
          _feed.value = feed;
          setState(() {
            _error = null;
            if (!feed.fromCache) _holdFilter = false;
            if (!_holdFilter &&
                _group != null &&
                !feed.alerts.any(
                  (a) => a.group == _group && !a.isExpiredAt(DateTime.now()),
                )) {
              _group = null;
            }
          });
        }
      },
      onError: (Object e) {
        done();
        if (mounted && gen == _generation) {
          _feed.value = _feed.value?.asFailed();
          setState(() => _error = e);
          _retryLater(const Duration(seconds: 5));
        }
      },
    );
    await first.future;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;

    final feed = _feed.value;
    if (feed == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (feed == null) {
      return _ErrorView(onRetry: _refresh);
    }

    final now = DateTime.now();
    final all = feed.orderedAt(now);
    final activeCount = all.where((a) => !a.isExpiredAt(now)).length;
    final countyCounts = <String, int>{};
    final groupCounts = <String, int>{};
    for (final a in all.where((a) => !a.isExpiredAt(now))) {
      groupCounts[a.group] = (groupCounts[a.group] ?? 0) + 1;
      for (final c in a.counties.toSet()) {
        countyCounts[c] = (countyCounts[c] ?? 0) + 1;
      }
    }
    final groups = groupOrder.where((g) => (groupCounts[g] ?? 0) > 0).toList();
    final group = groups.contains(_group) ? _group : null;
    if (group != _group && !_holdFilter) _group = null;
    final countyOrder = countyCounts.keys.toList()
      ..sort((a, b) => countyCounts[b]!.compareTo(countyCounts[a]!));
    final county = countyCounts.containsKey(_county) ? _county : null;
    if (county != _county && !_holdFilter) _county = null;
    final shown = all
        .where((a) => group == null || a.group == group)
        .where((a) => county == null || a.counties.contains(county))
        .toList();
    if (widget.onTopChanged case final notify?) {
      final top = shown.where((a) => !a.isExpiredAt(now)).firstOrNull;
      if (!identical(top, _top)) {
        _top = top;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) notify(top, _feed);
        });
      }
    }
    final locale = Localizations.localeOf(context).languageCode;
    final stale = feed.stale;
    final overdue = _sync?.overdueAt(DateTime.now()) ?? false;

    if (!feed.fromCache) _restore.apply();
    final list = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        controller: kIsWeb ? _list : null,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppLayout.pagePadding,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(t.activeAlerts, style: text.headlineMedium)),
              Text(
                t.activeCount(activeCount),
                style: text.labelMedium!.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          if (_sync case final sync?) ...[
            const SizedBox(height: 4),
            Text(
              sync.ok
                  ? (overdue
                        ? t.syncOverdue(absoluteTime(locale, sync.lastRunAt))
                        : t.lastSynced(absoluteTime(locale, sync.lastRunAt)))
                  : sync.lastOkAt == null
                  ? t.syncFailedNever
                  : t.syncFailedSince(absoluteTime(locale, sync.lastOkAt)),
              style: text.labelMedium!.copyWith(
                color: sync.ok && !overdue
                    ? AppColors.textMuted
                    : AppColors.attention,
              ),
            ),
          ] else if (feed.syncedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              t.lastSynced(absoluteTime(locale, feed.syncedAt)),
              style: text.labelMedium!.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (stale) ...[
            const SizedBox(height: 8),
            StaleBanner(feed: feed, onRetry: _refresh),
          ],
          const SizedBox(height: 16),
          _Filters(
            compact: widget.compactFilters,
            categoryLabel: t.category,
            countyLabel: t.byCounty,
            groups: [
              (value: null, label: t.filterAllTypes, icon: null),
              for (final g in groups)
                (
                  value: g,
                  label: '${groupLabel(t, g)} ${groupCounts[g] ?? 0}',
                  icon: groupIcon(g),
                ),
            ],
            group: group,
            onGroup: (g) => setState(() => _group = g),
            counties: [
              if (countyOrder.isNotEmpty) ...[
                (value: null, label: t.filterAll, icon: null),
                for (final c in countyOrder)
                  (
                    value: c,
                    label: t.countyCount(
                      countyName(c, locale),
                      countyCounts[c]!,
                    ),
                    icon: null,
                  ),
              ],
            ],
            county: county,
            onCounty: (c, {toggle = false}) =>
                setState(() => _county = toggle && county == c ? null : c),
          ),
          const SizedBox(height: 16),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  stale
                      ? t.noFreshData
                      : (group != null || county != null)
                      ? t.noFilteredAlerts
                      : t.noAlerts,
                  style: text.bodyMedium,
                ),
              ),
            ),
          for (final g in groupByRawId(shown, now))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: g.length > 1
                  ? AlertGroupCard(
                      alerts: g,
                      feed: _feed,
                      filter: (a) =>
                          (group == null || a.group == group) &&
                          (county == null || a.counties.contains(county)),
                    )
                  : AlertCard(
                      alert: g.first,
                      selected: widget.selectedUid == g.first.uid,
                      onTap: () =>
                          AlertOpener.openAlert(context, g.first, _feed),
                    ),
            ),
          const SizedBox(height: 8),
          _RecentlyEnded(
            repository: widget.repository,
            refresh: _endedRefresh,
            selectedUid: widget.selectedUid,
          ),
          if (widget.footer case final footer?) ...[
            const Divider(height: 32),
            footer,
            const SizedBox(height: 16),
          ],
        ],
      ),
    );

    if (!kIsWeb) return list;
    final major = all.where((a) => !a.isExpiredAt(now) && _isMajor(a)).toList();
    final sync = _sync;
    final String? majorNote = stale
        ? t.staleData
        : sync == null || (sync.ok && !overdue)
        ? null
        : sync.ok
        ? t.syncOverdue(absoluteTime(locale, sync.lastRunAt))
        : sync.lastOkAt == null
        ? t.syncFailedNever
        : t.syncFailedSince(absoluteTime(locale, sync.lastOkAt));
    return LayoutBuilder(
      builder: (context, c) => Column(
        children: [
          if (major.isNotEmpty)
            _MajorBanner(
              maxHeight: c.maxHeight * 0.4,
              alerts: major,
              note: majorNote,
              onTap: () {
                if (major.length == 1) {
                  AlertOpener.openAlert(context, major.single, _feed);
                  return;
                }
                setState(() {
                  _group = null;
                  _county = null;
                });
                if (!_list.hasClients) return;
                if (MediaQuery.disableAnimationsOf(context)) {
                  _list.jumpTo(0);
                } else {
                  _list.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
            ),
          Expanded(key: const ValueKey('home-alert-list'), child: list),
        ],
      ),
    );
  }
}


class _MajorBanner extends StatelessWidget {
  final List<Alert> alerts;
  final String? note;
  final VoidCallback onTap;
  final double maxHeight;
  const _MajorBanner({
    required this.alerts,
    required this.note,
    required this.onTap,
    required this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final extreme = alerts.any((a) => a.severity == 'extreme');
    final bg = extreme ? AppColors.sevRed : AppColors.sevOrange;
    final fg = extreme ? Colors.white : AppColors.onSevLight;
    return Material(
      color: bg,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppLayout.touchTarget,
                ),
                child: Semantics(
                  liveRegion: true,
                  label:
                      [
                        if (extreme) t.severityExtreme,
                        t.majorAlertsBanner(alerts.length),
                        ?note,
                      ].join(switch (Localizations.localeOf(context)
                          .languageCode) {
                        'zh' => '，',
                        'ja' => '、',
                        _ => ', ',
                      }),
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppLayout.pageMargin,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Symbols.warning_rounded,
                            color: fg,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (extreme)
                                Text(
                                  t.severityExtreme,
                                  style: text.labelLarge!.copyWith(
                                    color: fg,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              Text(
                                t.majorAlertsBanner(alerts.length),
                                style: text.titleMedium!.copyWith(
                                  color: fg,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (note case final n?)
                                Text(
                                  n,
                                  style: text.bodySmall!.copyWith(color: fg),
                                ),
                            ],
                          ),
                        ),
                        ExcludeSemantics(
                          child: Icon(
                            Symbols.chevron_right_rounded,
                            color: fg,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

typedef _Option = ({String? value, String label, IconData? icon});


class _Filters extends StatelessWidget {
  final bool compact;
  final String categoryLabel;
  final String countyLabel;
  final List<_Option> groups;
  final String? group;
  final ValueChanged<String?> onGroup;
  final List<_Option> counties;
  final String? county;
  final void Function(String? c, {bool toggle}) onCounty;
  const _Filters({
    required this.compact,
    required this.categoryLabel,
    required this.countyLabel,
    required this.groups,
    required this.group,
    required this.onGroup,
    required this.counties,
    required this.county,
    required this.onCounty,
  });

  static double _rowWidth(BuildContext context, List<_Option> options) {
    final style = Theme.of(context).textTheme.labelMedium!;
    final scaler = MediaQuery.textScalerOf(context);
    var w = 0.0;
    for (final o in options) {
      final tp = TextPainter(
        text: TextSpan(text: o.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      w += tp.width + 32 + 4 + 8 + (o.icon != null ? 24 : 0);
      tp.dispose();
    }
    return w;
  }

  Widget _chips(
    List<_Option> options,
    String? selected,
    void Function(String?) onTap,
  ) =>
      _HScroll(
        child: Row(
          children: [
            for (final o in options)
              _FilterChip(
                label: o.label,
                icon: o.icon,
                selected: selected == o.value,
                onTap: () => onTap(o.value),
              ),
          ],
        ),
      );

  Widget _dropdown(
    String label,
    List<_Option> options,
    String? selected,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String?>(
    key: ValueKey('$label:$selected'),
    initialValue: selected,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    items: [
      for (final o in options)
        DropdownMenuItem(
          value: o.value,
          child: Row(
            children: [
              if (o.icon != null) ...[
                Icon(o.icon, size: 18),
                const SizedBox(width: 6),
              ],
              Flexible(child: Text(o.label, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
    ],
    onChanged: onChanged,
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget chipsLayout() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chips(groups, group, onGroup),
        if (counties.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            countyLabel,
            style: text.labelMedium!.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          _chips(counties, county, (c) => onCounty(c, toggle: true)),
        ],
      ],
    );
    if (!compact) return chipsLayout();
    return LayoutBuilder(
      builder: (context, c) {
        final fits =
            _rowWidth(context, groups) <= c.maxWidth &&
            _rowWidth(context, counties) <= c.maxWidth;
        if (fits) return chipsLayout();
        final g = _dropdown(categoryLabel, groups, group, onGroup);
        if (counties.isEmpty) return g;
        final k = _dropdown(countyLabel, counties, county, onCounty);
        return c.maxWidth >= 380 * MediaQuery.textScalerOf(context).scale(1)
            ? Row(
                children: [
                  Expanded(child: g),
                  const SizedBox(width: 12),
                  Expanded(child: k),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [g, const SizedBox(height: 12), k],
              );
      },
    );
  }
}


class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.onSurface : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.onSurface : AppColors.outlineVariant,
            width: 2,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppLayout.touchTarget),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium!
                      .copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Symbols.cloud_off_rounded,
              size: 48,
              color: AppColors.outline,
            ),
            const SizedBox(height: 16),
            Text(
              t.loadFailed,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: Text(t.retry)),
          ],
        ),
      ),
    );
  }
}


class _RecentlyEnded extends StatefulWidget {
  final AlertRepository repository;

  final ValueListenable<int> refresh;
  final String? selectedUid;
  const _RecentlyEnded({
    required this.repository,
    required this.refresh,
    this.selectedUid,
  });

  @override
  State<_RecentlyEnded> createState() => _RecentlyEndedState();
}

class _RecentlyEndedState extends State<_RecentlyEnded> {
  Future<List<Alert>>? _future;
  bool _open = false;

  void _load() =>
      setState(() => _future = widget.repository.fetchRecentlyEnded());

  void _onRefresh() {
    if (_open) _load();
  }

  @override
  void initState() {
    super.initState();
    widget.refresh.addListener(_onRefresh);
  }

  @override
  void dispose() {
    widget.refresh.removeListener(_onRefresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        minTileHeight: AppLayout.touchTarget,
        shape: const Border(),
        title: Text(t.recentlyEnded, style: text.titleMedium),
        onExpansionChanged: (open) {
          _open = open;
          if (open) _load();
        },
        children: [
          FutureBuilder(
            future: _future,
            builder: (context, snap) {
              final loading = snap.connectionState == ConnectionState.waiting;
              if (loading && (snap.hasError || !snap.hasData)) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(t.loadFailed, style: text.bodySmall),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, AppLayout.touchTarget),
                        ),
                        onPressed: _load,
                        child: Text(t.retry),
                      ),
                    ],
                  ),
                );
              }
              final since = DateTime.now().subtract(const Duration(hours: 24));
              final list = snap.data
                  ?.where((a) => a.endedAt == null || a.endedAt!.isAfter(since))
                  .toList();
              if (list == null) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (list.isEmpty && !loading) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(t.noRecentlyEnded, style: text.bodySmall),
                );
              }
              return Column(
                children: [
                  if (loading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(
                        semanticsLabel: t.updating,
                      ),
                    ),
                  for (final a in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AlertCard(
                        alert: a,
                        selected: widget.selectedUid == a.uid,
                        onTap: () => AlertOpener.openAlert(context, a),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}


class _HScroll extends StatelessWidget {
  final Widget child;
  const _HScroll({required this.child});

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: const _MouseDragScrollBehavior(),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: child,
    ),
  );
}


class _MouseDragScrollBehavior extends MaterialScrollBehavior {
  const _MouseDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
