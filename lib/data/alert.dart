class Alert {
  final String uid;
  final String rawId;
  final String title;
  final String summary;
  final String sender;
  final String group;
  final String rawCategory;
  final String status;
  final DateTime? updated;
  final DateTime? expires;

  final DateTime? syncedAt;

  final DateTime? endedAt;

  final String? severity;

  final String? severitySource;

  final Map<String, String> aiSummaries;

  final String? aiSummarySource;

  final Map<String, String> countyLevels;

  final String? capLink;

  final List<String> counties;

  const Alert({
    required this.uid,
    required this.rawId,
    required this.title,
    required this.summary,
    required this.sender,
    required this.group,
    required this.rawCategory,
    required this.status,
    this.updated,
    this.expires,
    this.syncedAt,
    this.endedAt,
    this.severity,
    this.severitySource,
    this.aiSummaries = const {},
    this.aiSummarySource,
    this.counties = const [],
    this.capLink,
    this.countyLevels = const {},
  });

  bool isExpiredAt(DateTime now) => expires != null && !expires!.isAfter(now);

  Map<String, String?> get mapLevels => countyLevels.isEmpty
      ? {for (final c in counties) c: severity}
      : {
          for (final c in {...counties, ...countyLevels.keys})
            c: countyLevels[c],
        };

  String? aiSummaryFor(String lang) =>
      lang == 'zh' && aiSummarySource != 'AI 摘要' ? null : aiSummaries[lang];

  factory Alert.fromMap(Map<String, dynamic> m) => Alert(
    uid: m['uid'] as String? ?? '',
    rawId: m['raw_id'] as String? ?? '',
    title: m['title'] as String? ?? '',
    summary: m['summary'] as String? ?? '',
    sender: m['sender'] as String? ?? '',
    group: m['group'] as String? ?? '其他',
    rawCategory: m['raw_category'] as String? ?? '',
    status: m['status'] as String? ?? '',
    updated: DateTime.tryParse(m['updated'] as String? ?? ''),
    expires: DateTime.tryParse(m['expires'] as String? ?? ''),
    endedAt: switch (m['ended_at']) {
      final DateTime d => d,
      final String s => DateTime.tryParse(s),
      _ => null,
    },
    syncedAt: switch (m['synced_at']) {
      final DateTime d => d,
      final String s => DateTime.tryParse(s),
      _ => null,
    },
    severity: m['severity'] as String?,
    capLink: m['cap_link'] as String?,
    countyLevels: {
      for (final MapEntry(:key, :value)
          in ((m['county_levels'] as Map?) ?? const {}).entries)
        if (key is String && value is String) key: value,
    },
    severitySource: m['severity_source'] as String?,
    aiSummaries: {
      for (final (lang, key) in const [
        ('zh', 'ai_summary'),
        ('en', 'ai_summary_en'),
        ('ja', 'ai_summary_ja'),
      ])
        if (m[key] case final String v when v.isNotEmpty) lang: v,
    },
    aiSummarySource: m['ai_summary_source'] as String?,
    counties: [...?(m['counties'] as List?)?.cast<String>()],
  );
}
