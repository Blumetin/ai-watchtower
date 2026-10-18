import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/alert.dart';
import '../data/alert_repository.dart' show AlertFeed;
import '../data/push_prefs.dart' show countyName;
import '../l10n/app_localizations.dart';
import '../l10n/fixed_terms.dart';
import '../theme.dart';
import '../widgets/alert_type_icon.dart';
import '../widgets/call.dart';
import '../widgets/stale_banner.dart';
import '../widgets/taiwan_map.dart';
import '../widgets/time_format.dart';

const _finePrint = Color(0xFF5F6368);

class AlertDetailScreen extends StatefulWidget {
  final Alert alert;

  final ValueListenable<AlertFeed?>? feed;

  final bool embedded;
  const AlertDetailScreen({
    super.key,
    required this.alert,
    this.feed,
    this.embedded = false,
  });

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  late Alert _last = widget.alert;

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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final f = widget.feed;
      if (f == null) {
        return _build(context, _last, null, ended: false, width: c.maxWidth);
      }
      return ValueListenableBuilder(
        valueListenable: f,
        builder: (context, value, _) {
          final latest = value?.alerts
              .where((a) => a.uid == widget.alert.uid)
              .firstOrNull;
          if (latest != null) _last = latest;
          final ended = value != null && !value.stale && latest == null;
          return _build(context, _last, value, ended: ended, width: c.maxWidth);
        },
      );
    },
  );

  Widget _build(
    BuildContext context,
    Alert alert,
    AlertFeed? feed, {
    required bool ended,
    required double width,
  }) {
    final t = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final phoneLatin =
        _appLayout(context) &&
        MediaQuery.sizeOf(context).shortestSide < 600 &&
        !const {'zh', 'ja'}.contains(locale);
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final phoneLandscape =
        _appLayout(context) &&
        !widget.embedded &&
        size.shortestSide < 600 &&
        size.width > size.height;
    final columnW = phoneLandscape
        ? math.min(
            560.0,
            width - safe.left - safe.right - AppLayout.pageMargin * 2,
          )
        : null;
    final pagePadding = columnW == null
        ? AppLayout.pagePadding
        : EdgeInsets.fromLTRB(
            safe.left + (width - safe.left - safe.right - columnW) / 2,
            AppLayout.pagePadding.top,
            safe.right + (width - safe.left - safe.right - columnW) / 2,
            AppLayout.pagePadding.bottom + safe.bottom,
          );
    final theme = Theme.of(context);
    final text = phoneLatin
        ? theme.textTheme.copyWith(
            bodyLarge: theme.textTheme.bodyLarge!.copyWith(
              fontSize: 17,
              height: 1.5,
            ),
            bodyMedium: theme.textTheme.bodyMedium!.copyWith(
              fontSize: 16,
              height: 1.5,
            ),
            bodySmall: theme.textTheme.bodySmall!.copyWith(height: 1.5),
            titleMedium: theme.textTheme.titleMedium!.copyWith(fontSize: 17),
          )
        : theme.textTheme;
    final color = severityColor(alert.severity);
    final sevLabel = severityLabel(t, alert.severity);
    final aiSummary = alert.aiSummaryFor(locale);
    final original = alert.summary.isEmpty ? alert.title : alert.summary;

    final countyItems = [
      for (final c in alert.counties)
        switch (severityLabel(t, alert.mapLevels[c])) {
          final l? => t.countyWithLevel(countyName(c, locale), l),
          null => countyName(c, locale),
        },
    ];
    final countySep = locale == 'zh' || locale == 'ja' ? '、' : ', ';

    final list = ListView(
      padding: pagePadding,
      children: [
        if (feed != null && feed.stale) ...[
          StaleBanner(feed: feed),
          const SizedBox(height: 16),
        ],
        if (alert.endedAt != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppLayout.radius),
            ),
            child: Text(
              t.alertEnded(absoluteTime(locale, alert.endedAt)),
              style: text.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
        ] else if (!ended && alert.isExpiredAt(DateTime.now())) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppLayout.radius),
            ),
            child: Text(t.alertExpired, style: text.bodySmall),
          ),
          const SizedBox(height: 16),
        ],
        if (ended) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppLayout.radius),
            ),
            child: Text(
              t.alertNoLongerActive,
              style: text.bodySmall!.copyWith(color: AppColors.attention),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Theme(
          data: theme,
          child: Builder(
            builder: (context) {
              final compact =
                  MediaQuery.sizeOf(context).width < 600 && !phoneLandscape;
              final iconRadius = phoneLandscape
                  ? 28.0
                  : (compact ? 32.0 : 40.0);
              final title = titleText(
                alert.title,
                alert.rawCategory,
                locale,
                fallback: groupLabel(t, alert.group),
              );
              final Widget icon = ExcludeSemantics(
                child: CircleAvatar(
                  radius: iconRadius,
                  backgroundColor: color.withValues(
                    alpha: color == AppColors.sevYellow ? 0.45 : 0.15,
                  ),
                  child: AlertTypeIcon(
                    group: alert.group,
                    rawCategory: alert.rawCategory,
                    color: severityBorder(alert.severity) ?? color,
                    size: iconRadius * 1.3,
                  ),
                ),
              );
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        26,
                        20,
                        20,
                        20,
                      ),
                      child: _HeaderBody(
                        icon: icon,
                        iconWidth: iconRadius * 2,
                        title: title,
                        category: groupLabel(t, alert.group),
                        severity: alert.severity,
                        severityText: sevLabel,
                        color: color,
                        compact: compact,
                        smallChip: compact || phoneLandscape,
                        cjk: const {'zh', 'ja'}.contains(locale),
                      ),
                    ),
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      bottom: 0,
                      width: 6,
                      child: ColoredBox(color: color),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        if (alert.mapLevels.isNotEmpty) ...[
          TaiwanCountyMap(
            levels: alert.mapLevels,
            lang: locale,
            title: t.affectedCounties,
            heightFactor: phoneLatin ? 0.30 : 0.32,
            legendFontSize: phoneLatin ? 14 : null,
            moreLabelSlots: phoneLatin,
            minHeight: phoneLatin ? 220 : null,
            fixedHeight: columnW == null
                ? null
                : (columnW * 0.5).clamp(240.0, 280.0),
          ),
          const SizedBox(height: 24),
        ],
        if (aiSummary != null) ...[
          Text(aiSummary, style: text.bodyLarge),
          const SizedBox(height: 8),
          Text(
            t.aiSummaryDisclaimer,
            style: text.bodySmall!.copyWith(
              color: _finePrint,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              fontVariations: const [FontVariation.weight(400)],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Theme(
            data: (phoneLatin ? theme.copyWith(textTheme: text) : theme)
                .copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              minTileHeight: AppLayout.touchTarget,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: Text(t.showOriginalText, style: text.titleSmall),
              children: [
                Text(original, style: text.bodyMedium),
                if (locale != 'zh') ...[
                  const SizedBox(height: 8),
                  Text(
                    t.sourceLanguageNote,
                    style: text.bodySmall!.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          Text(
            t.originalText,
            style: text.labelMedium!.copyWith(color: _finePrint),
          ),
          const SizedBox(height: 4),
          Text(original, style: text.bodyLarge),
          if (locale != 'zh') ...[
            const SizedBox(height: 8),
            Text(
              t.sourceLanguageNote,
              style: text.bodySmall!.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
        const SizedBox(height: 24),
        if (locale != 'zh' &&
            titleText(
                  alert.title,
                  alert.rawCategory,
                  locale,
                  fallback: groupLabel(t, alert.group),
                ) !=
                alert.title)
          _InfoRow(label: t.originalTitle, value: alert.title),
        if (countyItems.isNotEmpty)
          _InfoRow(
            label: t.affectedCounties,
            value: countyItems.join(countySep),
            items: [
              for (final (i, item) in countyItems.indexed)
                i < countyItems.length - 1 ? '$item$countySep' : item,
            ],
          ),
        _InfoRow(
          label: t.category,
          value: switch ((
            groupLabel(t, alert.group),
            alert.rawCategory.isEmpty
                ? ''
                : categoryName(alert.rawCategory, locale),
          )) {
            (final g, final c) when c.isEmpty || c == g => g,
            (final g, final c) =>
              '$g${locale == 'zh' || locale == 'ja' ? '／' : ' / '}$c',
          },
        ),
        _InfoRow(
          label: t.updatedAt,
          value: absoluteTime(locale, alert.updated),
        ),
        _InfoRow(
          label: t.expiresAt,
          value: alert.expires == null
              ? t.noExpiry
              : absoluteTime(locale, alert.expires),
        ),
        const SizedBox(height: 24),
        _SourceBox(alert: alert, locale: locale, aiShown: aiSummary != null),
        const SizedBox(height: 40),
        Center(child: Text(t.needHelp, style: text.bodySmall)),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.sevRed),
          onPressed: () => callNumber(context, '119'),
          icon: const Icon(Symbols.call_rounded),
          label: Text(t.callEmergency),
        ),
      ],
    );
    final body = phoneLatin
        ? Theme(
            data: theme.copyWith(textTheme: text),
            child: list,
          )
        : list;
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(t.alertDetail)),
      body: body,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  final List<String>? items;
  const _InfoRow({required this.label, required this.value, this.items});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final valueStyle = text.bodySmall!.copyWith(
      color: AppColors.onSurfaceVariant,
    );
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
            width: 128,
            child: Text(
              label,
              style: text.labelMedium!.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: switch (items) {
              final parts? => Semantics(
                label: value,
                child: ExcludeSemantics(
                  child: Wrap(
                    children: [
                      for (final part in parts) Text(part, style: valueStyle),
                    ],
                  ),
                ),
              ),
              null => Text(value, style: valueStyle),
            },
          ),
        ],
      ),
    );
  }
}

class _SourceBox extends StatelessWidget {
  final Alert alert;
  final String locale;

  final bool aiShown;
  const _SourceBox({
    required this.alert,
    required this.locale,
    required this.aiShown,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppLayout.radius),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppLayout.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.verified_rounded, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text(t.dataSource, style: text.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            aiShown
                ? t.dataSourceDetailShort(senderName(alert.sender, locale))
                : t.dataSourceDetail(senderName(alert.sender, locale)),
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HeaderBody extends StatelessWidget {
  final Widget icon;
  final double iconWidth;
  final String title;
  final String category;
  final String? severity;
  final String? severityText;
  final Color color;
  final bool compact;
  final bool smallChip;
  final bool cjk;

  const _HeaderBody({
    required this.icon,
    required this.iconWidth,
    required this.title,
    required this.category,
    required this.severity,
    required this.severityText,
    required this.color,
    required this.compact,
    required this.smallChip,
    required this.cjk,
  });

  static const _gap = 16.0;
  static const _chipGap = 12.0;

  static final _units = RegExp(r'[A-Za-z0-9][A-Za-z0-9.\-]*|\S');

  String? get _sev => (severityText?.isNotEmpty ?? false) ? severityText : null;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    final start = compact ? (cjk ? 32.0 : 28.0) : (cjk ? 36.0 : 32.0);
    final floor = cjk ? 24.0 : 18.0;
    final base = text.headlineLarge!.copyWith(fontSize: start, height: 1.2);
    final chipStyle = text.titleMedium!.copyWith(
      fontSize: smallChip ? 18 : 20,
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation.weight(700)],
      color: onSeverityColor(severity),
    );
    final chipPad = smallChip
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 6);

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final tp = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: scaler,
          locale: Localizations.localeOf(context),
          maxLines: 1,
        );
        final defaultStyle = DefaultTextStyle.of(context).style;
        final bold = MediaQuery.boldTextOf(context);
        final letterSpacing = MediaQuery.maybeLetterSpacingOverrideOf(context);
        final wordSpacing = MediaQuery.maybeWordSpacingOverrideOf(context);
        TextStyle effective(TextStyle st) {
          var s = st.inherit ? defaultStyle.merge(st) : st;
          if (bold) s = s.merge(const TextStyle(fontWeight: FontWeight.bold));
          return s.copyWith(
            letterSpacing: letterSpacing ?? s.letterSpacing,
            wordSpacing: wordSpacing ?? s.wordSpacing,
          );
        }

        double width(String s, TextStyle st) =>
            (tp
                  ..text = TextSpan(text: s, style: effective(st))
                  ..layout())
                .width;
        final byChar = cjk;
        double longestWord(TextStyle st) =>
            (byChar
                    ? _units.allMatches(title).map((m) => m.group(0)!)
                    : title.split(RegExp(r'\s+')))
                .fold(0.0, (a, u) => math.max(a, width(u, st)));
        final sev = _sev;
        final chipW = sev == null
            ? 0.0
            : width(sev, chipStyle) +
                  chipPad.horizontal +
                  (severityBorder(severity) == null ? 0 : 3);

        TextStyle? oneLine(double avail) {
          if (avail <= 0 || title.trim().isEmpty || title.contains('\n')) {
            return null;
          }
          var st = base;
          for (var i = 0; i < 4; i++) {
            final tw = width(title, st);
            if (tw <= avail) return st;
            final size = st.fontSize!;
            if (!compact || size <= floor) return null;
            st = st.copyWith(
              fontSize: math.max(floor, (size * avail / tw).floorToDouble()),
            );
          }
          return width(title, st) <= avail ? st : null;
        }

        TextStyle wrapping(double avail) {
          if (avail <= 0 || title.trim().isEmpty) return base;
          var st = base;
          for (var i = 0; i < 4; i++) {
            final lw = longestWord(st);
            final size = st.fontSize!;
            if (lw <= avail || size <= floor || !compact) return st;
            st = st.copyWith(
              fontSize: math.max(floor, (size * avail / lw).floorToDouble()),
            );
          }
          return st;
        }

        final beside = w - iconWidth - _gap;
        final besideStyle = wrapping(beside);
        Widget layout;
        final row = _sev == null
            ? oneLine(beside)
            : oneLine(beside - chipW - _chipGap);
        if (row != null) {
          layout = _row(icon, _titleWidget(row), _chip(chipStyle, chipPad));
        } else if (chipW <= beside && longestWord(besideStyle) <= beside) {
          final st = besideStyle;
          layout = Row(
            children: [
              icon,
              const SizedBox(width: _gap),
              Expanded(
                child: _stack(_titleWidget(st), _chip(chipStyle, chipPad)),
              ),
            ],
          );
        } else {
          layout = SizedBox(
            width: w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(height: 12),
                _stack(_titleWidget(wrapping(w)), _chip(chipStyle, chipPad)),
              ],
            ),
          );
        }
        tp.dispose();
        final lang = Localizations.localeOf(context).languageCode;
        final sep = switch (lang) {
          'zh' => '，',
          'ja' => '、',
          _ => ', ',
        };
        return Semantics(
          header: true,
          label: [
            title,
            ?_sev,
            if (category.isNotEmpty && category != title) category,
          ].join(sep),
          excludeSemantics: true,
          child: layout,
        );
      },
    );
  }

  Widget _titleWidget(TextStyle st) =>
      Text(title, style: st, textAlign: TextAlign.center);

  Widget? _chip(TextStyle st, EdgeInsets pad) => _sev == null
      ? null
      : Container(
          padding: pad,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: switch (severityBorder(severity)) {
              final c? => Border.all(color: c, width: 1.5),
              null => null,
            },
          ),
          child: Text(
            _sev!,
            style: st.copyWith(height: 1.2),
            textAlign: TextAlign.center,
          ),
        );

  Widget _row(Widget icon, Widget title, Widget? chip) => Row(
    children: [
      icon,
      const SizedBox(width: _gap),
      Expanded(child: title),
      if (chip != null) ...[const SizedBox(width: _chipGap), chip],
    ],
  );

  Widget _stack(Widget title, Widget? chip) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      title,
      if (chip != null) ...[const SizedBox(height: 8), chip],
    ],
  );
}


bool _appLayout(BuildContext context) =>
    !kIsWeb ||
    ((defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android) &&
        MediaQuery.sizeOf(context).shortestSide < 600);
