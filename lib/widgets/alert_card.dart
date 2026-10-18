import 'package:flutter/material.dart';

import '../data/alert.dart';
import '../l10n/app_localizations.dart';
import '../l10n/fixed_terms.dart';
import '../theme.dart';
import 'alert_type_icon.dart';
import 'time_format.dart';

class AlertCard extends StatelessWidget {
  final Alert alert;
  final VoidCallback onTap;

  final bool selected;
  const AlertCard({
    super.key,
    required this.alert,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final color = severityColor(alert.severity);
    final sevLabel = severityLabel(t, alert.severity);
    final ended = alert.endedAt != null;
    final expired = ended || alert.isExpiredAt(DateTime.now());
    final lang = Localizations.localeOf(context).languageCode;
    final displayTitle = titleText(
      alert.title,
      alert.rawCategory,
      lang,
      fallback: groupLabel(t, alert.group),
    );
    final categoryLabel = alert.rawCategory.isNotEmpty
        ? categoryName(alert.rawCategory, lang)
        : groupLabel(t, alert.group);
    final ai = alert.aiSummaryFor(lang);
    final summary = ai ?? alert.summary;
    final summaryLabel = ai == null && lang != 'zh' ? t.originalText : null;
    final chipLabel = expired ? (ended ? t.ended : t.expired) : sevLabel;
    final timeLabel = ended
        ? t.endedAtShort(relativeTime(t, alert.endedAt))
        : relativeTime(t, alert.updated);
    final muted = text.labelMedium!.copyWith(color: AppColors.textMuted);

    return Semantics(
      selected: selected ? true : null,
      child: Material(
        color: expired ? AppColors.surfaceContainerLow : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radius),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.cardBorder,
            width: AppLayout.borderWidth,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
                    Semantics(
                      header: true,
                      label: [
                        ?chipLabel,
                        displayTitle,
                        senderName(alert.sender, lang),
                        timeLabel,
                        if (categoryLabel != displayTitle) categoryLabel,
                      ].where((e) => e.isNotEmpty).join(', '),
                      child: ExcludeSemantics(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final chip = chipLabel == null
                                ? null
                                : _SeverityChip(
                                    label: chipLabel,
                                    color: expired
                                        ? AppColors.onSurfaceVariant
                                        : color,
                                    textColor: expired
                                        ? Colors.white
                                        : onSeverityColor(alert.severity),
                                  );
                            final icon = AlertTypeIcon(
                              group: alert.group,
                              rawCategory: alert.rawCategory,
                              size: 20,
                              color: AppColors.onSurfaceVariant,
                            );
                            final timeOwnLine =
                                !const {'zh', 'ja'}.contains(lang) &&
                                timeLabel.isNotEmpty;
                            final extra = [
                              if (timeLabel.isNotEmpty && !timeOwnLine)
                                (keepTogether(timeLabel, lang), muted),
                              if (categoryLabel != displayTitle)
                                (
                                  categoryLabel,
                                  text.labelMedium!.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                            ];
                            final base = text.headlineSmall!.fontSize ?? 20;
                            final scale =
                                MediaQuery.textScalerOf(context).scale(base) /
                                base;
                            if (c.maxWidth / scale < 220) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      icon,
                                      ?chip,
                                      for (final (e, st) in extra)
                                        Text(e, style: st),
                                      if (timeOwnLine)
                                        Text(timeLabel, style: muted),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(displayTitle, style: text.headlineSmall),
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
                                          alignment:
                                              PlaceholderAlignment.middle,
                                          child: Padding(
                                            padding:
                                                const EdgeInsetsDirectional.only(
                                                  end: 8,
                                                ),
                                            child: icon,
                                          ),
                                        ),
                                        TextSpan(
                                          text: displayTitle,
                                          style: text.headlineSmall,
                                        ),
                                        for (final (e, st) in extra)
                                          TextSpan(text: '  $e', style: st),
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
                                  child: Text(timeLabel, style: muted),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    if (summary.isNotEmpty && summary != alert.title) ...[
                      const SizedBox(height: 8),
                      if (summaryLabel != null)
                        Text(
                          summaryLabel,
                          style: text.labelMedium!.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      Text(
                        summary,
                        style: text.bodyMedium!.copyWith(height: 1.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: AppLayout.accentBarWidth,
                child: ColoredBox(color: expired ? AppColors.outline : color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _SeverityChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      softWrap: false,
      style: Theme.of(context).textTheme.labelMedium!
          .copyWith(color: textColor),
    ),
  );
}
