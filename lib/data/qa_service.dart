import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:cloud_functions/cloud_functions.dart';

class QaSource {
  final String name;
  final String url;

  final String title;
  const QaSource(this.name, this.url, [this.title = '']);

  String get label => title.isEmpty ? name : '$name｜$title';
}

class QaAnswer {
  final String answer;
  final List<QaSource> sources;

  final bool crisis;

  final bool crisisCheck;

  final bool prediction;

  final String route;
  const QaAnswer(
    this.answer,
    this.sources, {
    this.crisis = false,
    this.crisisCheck = false,
    this.prediction = false,
    this.route = '',
  });
}

enum QaReportReason { incorrect, outdated, offensive, other }

class QaReport {
  final String question;
  final String answer;
  final QaReportReason reason;
  final String note;
  final String lang;
  final String route;
  const QaReport({
    required this.question,
    required this.answer,
    required this.reason,
    required this.note,
    required this.lang,
    required this.route,
  });

  static const maxQuestion = 300;
  static const maxAnswer = 8000;
  static const maxNote = 200;
}

abstract class QaService {
  bool get isPreview;

  bool get canReport;
  Future<void> report(QaReport report);
  Future<QaAnswer> ask(
    String question, {
    required String locale,
    String? crisisCheckOf,
    bool checkedBefore = false,
  });
}

class MockQaService implements QaService {
  final String Function(String locale) sampleAnswer;
  MockQaService(this.sampleAnswer);

  @override
  bool get isPreview => true;

  @override
  bool get canReport => false;

  @override
  Future<void> report(QaReport report) =>
      Future.error(const QaException(QaError.failed));

  @override
  Future<QaAnswer> ask(
    String question, {
    required String locale,
    String? crisisCheckOf,
    bool checkedBefore = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return QaAnswer(sampleAnswer(locale), const [
      QaSource('NFA', 'https://www.nfa.gov.tw/'),
    ]);
  }
}

class CallableQaService implements QaService {
  static const maxLength = 300;
  final FirebaseFunctions _functions;
  CallableQaService([FirebaseFunctions? functions])
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1');

  @override
  bool get isPreview => false;

  @override
  bool get canReport => true;

  @override
  Future<void> report(QaReport r) async {
    String cut(String v, int n) => v.trim().characters.take(n).toString();
    try {
      await _functions.httpsCallable('report_answer').call({
        'question': cut(r.question, QaReport.maxQuestion),
        'answer': cut(r.answer, QaReport.maxAnswer),
        'reason': r.reason.name,
        if (r.note.trim().isNotEmpty) 'note': cut(r.note, QaReport.maxNote),
        'lang': r.lang,
        if (r.route.isNotEmpty) 'route': r.route,
      });
    } on FirebaseFunctionsException catch (e) {
      throw QaException(switch (e.code) {
        'resource-exhausted' when (e.message ?? '').contains('today') =>
          QaError.reportDailyFull,
        'resource-exhausted' => QaError.rateLimited,
        _ => QaError.failed,
      });
    }
  }

  @override
  Future<QaAnswer> ask(
    String question, {
    required String locale,
    String? crisisCheckOf,
    bool checkedBefore = false,
  }) async {
    if (question.characters.length > maxLength) {
      throw const QaException(QaError.tooLong);
    }
    try {
      final res = await _functions.httpsCallable('ask').call({
        'question': question,
        'lang': locale,
        if (crisisCheckOf != null)
          'crisis_check_of': crisisCheckOf.characters
              .take(maxLength)
              .toString(),
        if (checkedBefore) 'checked_before': true,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      if (kDebugMode) debugPrint('ask route=${data['route']}');
      final crisis = data['crisis'] == true || data['route'] == 'crisis';
      return QaAnswer(
        data['answer'] as String? ?? '',
        [
          for (final s in (data['sources'] as List? ?? []))
            QaSource(
              (s as Map)['name'] as String? ?? '',
              s['url'] as String? ?? '',
              s['title'] as String? ?? '',
            ),
        ],
        crisis: crisis,
        crisisCheck:
            !crisis &&
            (data['crisis_check'] == true || data['route'] == 'crisis_check'),
        prediction: data['route'] == 'prediction',
        route: data['route'] as String? ?? '',
      );
    } on FirebaseFunctionsException catch (e) {
      throw QaException(
        e.code == 'resource-exhausted' ? QaError.rateLimited : QaError.failed,
      );
    }
  }
}

enum QaError { rateLimited, tooLong, failed, reportDailyFull }

const kContactEmail = 'watchtowertw.support@gmail.com';

class QaException implements Exception {
  final QaError error;
  const QaException(this.error);
}

class UnavailableQaService implements QaService {
  const UnavailableQaService();

  @override
  bool get isPreview => false;

  @override
  bool get canReport => false;

  @override
  Future<void> report(QaReport report) =>
      Future.error(const QaException(QaError.failed));

  @override
  Future<QaAnswer> ask(
    String question, {
    required String locale,
    String? crisisCheckOf,
    bool checkedBefore = false,
  }) => Future.error(const QaException(QaError.failed));
}
