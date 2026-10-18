import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

String relativeTime(AppLocalizations t, DateTime? time, [DateTime? now]) {
  if (time == null) return '';
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return t.justNow;
  if (diff.inHours < 1) return t.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return t.hoursAgo(diff.inHours);
  return t.daysAgo(diff.inDays);
}

String absoluteTime(String locale, DateTime? time) {
  if (time == null) return '';
  final tw = time.toUtc().add(const Duration(hours: 8));
  if (locale == 'en') {
    return '${DateFormat('HH:mm, MMMM d, y', 'en').format(tw)} (Taiwan time, UTC+8)';
  }
  return DateFormat('y/MM/dd HH:mm', 'zh').format(tw);
}

String keepTogether(String s, String lang) =>
    const {'zh', 'ja'}.contains(lang) ? s : s.replaceAll(' ', '\u00A0');
