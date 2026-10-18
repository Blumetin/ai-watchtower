import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/alert.dart';
import '../data/alert_repository.dart';
import '../l10n/app_localizations.dart';
import '../l10n/fixed_terms.dart';
import '../theme.dart';
import '../web/site_chrome.dart' show sitePage;
import 'alert_card.dart';
import 'alert_type_icon.dart';
import 'alert_opener.dart';
import 'stale_banner.dart';
import 'time_format.dart';

List<List<Alert>> groupByRawId(List<Alert> alerts, [DateTime? now]) {
  final at = now ?? DateTime.now();
  final groups = <String, List<Alert>>{};
  final order = <List<Alert>>[];
  for (final a in alerts) {
    final key =
        '${a.rawId.isEmpty ? a.uid : a.rawId}|${a.isExpiredAt(at) ? 'x' : 'a'}';
    final g = groups[key];
    if (g == null) {
      final created = [a];
      groups[key] = created;
      order.add(created);
    } else {
      g.add(a);
    }
  }
  return order;
}

class AlertGroupCard extends StatelessWidget {
  final List<Alert> alerts;
  final ValueListenable<AlertFeed?>? feed;

  final bool Function(Alert)? filter;
  const AlertGroupCard({
    super.key,
    required this.alerts,
    this.feed,
    this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final first = alerts.first;
    final expired = first.isExpiredAt(DateTime.now());
    final color = expired ? AppColors.outline : severityColor(first.severity);
    final sevLabel = expired ? t.expired : severityLabel(t, first.severity);
    final title = titleText(
      first.title,
      first.rawCategory,
      lang,
      fallback: groupLabel(t, first.group),
    );
    final newest = alerts
        .map((a) => a.updated)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (m, d) => m == null || d.isAfter(m) ? d : m);

    return Material(
      color: expired ? AppColors.surfaceContainerLow : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radius),
        side: const BorderSide(
          color: AppColors.cardBorder,
          width: AppLayout.borderWidth,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (AlertOpener.openGroupIn(context, alerts, feed, filter)) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  AlertGroupScreen(alerts: alerts, feed: feed, filter: filter),
            ),
          );
        },
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                20 + AppLayout.accentBarWidth,
                20,
                20,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final icon = ExcludeSemantics(
                        child: AlertTypeIcon(
                          group: first.group,
                          rawCategory: first.rawCategory,
                          size: 20,
                          color: AppColors.onSurfaceVariant,
                        ),
                      );
                      final chip = sevLabel == null
                          ? null
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: expired
                                    ? AppColors.onSurfaceVariant
                                    : color,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                sevLabel,
                                style: text.labelMedium!.copyWith(
                                  color: expired
                                      ? Colors.white
                                      : onSeverityColor(first.severity),
                                ),
                              ),
                            );
                      final spokenHeading = t.groupedTitle(
                        title,
                        alerts.length,
                      );
                      final count = '${alerts.length} ';
                      final at = spokenHeading.lastIndexOf(count);
                      final heading =
                          at < 0 || const {'zh', 'ja'}.contains(lang)
                          ? spokenHeading
                          : spokenHeading.replaceRange(
                              at,
                              at + count.length,
                              '${alerts.length}\u00A0',
                            );
                      final spoken = relativeTime(t, newest);
                      final time = keepTogether(spoken, lang);
                      final timeOwnLine = !const {'zh', 'ja'}.contains(lang);
                      final muted = text.labelMedium!.copyWith(
                        color: AppColors.textMuted,
                      );
                      final base = text.headlineSmall!.fontSize ?? 20;
                      final scale =
                          MediaQuery.textScalerOf(context).scale(base) / base;
                      if (c.maxWidth / scale < 220) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                icon,
                                ?chip,
                                Text(
                                  time,
                                  style: muted,
                                  semanticsLabel: spoken,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              heading,
                              style: text.headlineSmall,
                              semanticsLabel: spokenHeading,
                            ),
                          ],
                        );
                      }
                      final row = Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 8,
                                      ),
                                      child: icon,
                                    ),
                                  ),
                                  TextSpan(
                                    text: heading,
                                    style: text.headlineSmall,
                                    semanticsLabel: spokenHeading,
                                  ),
                                  if (!timeOwnLine)
                                    TextSpan(
                                      text: '  $time',
                                      style: muted,
                                      semanticsLabel: '  $spoken',
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (chip != null)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 8,
                              ),
                              child: chip,
                            ),
                        ],
                      );
                      if (!timeOwnLine) return row;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          row,
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 28,
                              top: 2,
                            ),
                            child: Text(
                              time,
                              style: muted,
                              semanticsLabel: spoken,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.groupedHint,
                    style: text.bodySmall!.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    senderName(first.sender, lang),
                    style: text.labelMedium!.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: AppLayout.accentBarWidth,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class AlertGroupScreen extends StatefulWidget {
  final List<Alert> alerts;
  final ValueListenable<AlertFeed?>? feed;
  final bool Function(Alert)? filter;

  
  final bool embedded;
  const AlertGroupScreen({
    super.key,
    required this.alerts,
    this.feed,
    this.filter,
    this.embedded = false,
  });

  @override
  State<AlertGroupScreen> createState() => _AlertGroupScreenState();
}

class _AlertGroupScreenState extends State<AlertGroupScreen> {
  
  late final Map<String, Alert> _members = {
    for (final a in widget.alerts) a.uid: a,
  };
  final _removed = <String>{};
  late final bool _wasExpired = widget.alerts.first.isExpiredAt(DateTime.now());

  
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _sync(AlertFeed value) {
    final rawId = widget.alerts.first.rawId;
    final byUid = {for (final a in value.alerts) a.uid: a};
    for (final uid in _members.keys.toList()) {
      final latest = byUid[uid];
      if (latest != null) {
        _members[uid] = latest;
      } else if (!value.stale) {
        _members.remove(uid);
        _removed.add(uid);
      }
    }
    if (!value.stale) {
      for (final uid in _removed.toList()) {
        if (byUid[uid] case final a?) {
          _removed.remove(uid);
          _members[uid] = a;
        }
      }
    }
    if (!_wasExpired && rawId.isNotEmpty) {
      final now = DateTime.now();
      for (final a in value.alerts) {
        if (a.rawId == rawId &&
            !_members.containsKey(a.uid) &&
            !_removed.contains(a.uid) &&
            !a.isExpiredAt(now) &&
            (widget.filter?.call(a) ?? true)) {
          _members[a.uid] = a;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feed;
    if (f == null) return _build(context, widget.alerts, null, ended: false);
    return ValueListenableBuilder(
      valueListenable: f,
      builder: (context, value, _) {
        if (value != null) _sync(value);
        final now = DateTime.now();
        final list =
            _members.values
                .where((a) => widget.filter?.call(a) ?? true)
                .toList()
              ..sort((a, b) {
                final e =
                    (a.isExpiredAt(now) ? 1 : 0) - (b.isExpiredAt(now) ? 1 : 0);
                return e != 0 ? e : compareAlerts(a, b);
              });
        if (list.isEmpty) {
          final elsewhere = _members.isNotEmpty;
          return _build(
            context,
            const [],
            value,
            ended: true,
            outOfScope: elsewhere,
          );
        }
        return _build(context, list, value, ended: false);
      },
    );
  }

  Widget _build(
    BuildContext context,
    List<Alert> list,
    AlertFeed? feed, {
    required bool ended,
    bool outOfScope = false,
  }) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final first = list.isNotEmpty ? list.first : widget.alerts.first;
    final title = titleText(
      first.title,
      first.rawCategory,
      lang,
      fallback: groupLabel(t, first.group),
    );
    return sitePage(
      embedded: widget.embedded,
      title: t.groupedTitle(title, list.length),
      body: ListView(
        padding: AppLayout.pagePadding,
        children: [
          if (feed != null && feed.stale) ...[
            StaleBanner(feed: feed),
            const SizedBox(height: 16),
          ],
          if (ended) ...[
            Text(
              outOfScope ? t.noLongerMatchesFilter : t.alertNoLongerActive,
              style: text.bodySmall!.copyWith(color: AppColors.attention),
            ),
            const SizedBox(height: 16),
          ],
          for (final a in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AlertCard(
                alert: a,
                onTap: () => AlertOpener.openAlert(context, a, widget.feed),
              ),
            ),
        ],
      ),
    );
  }
}
