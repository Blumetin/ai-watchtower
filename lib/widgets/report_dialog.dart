import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../data/qa_service.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

Future<bool?> showReportDialog(
  BuildContext context, {
  required QaService service,
  required String question,
  required String answer,
  required String route,
  Widget? crisisRow,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ReportDialog(
    service: service,
    question: question,
    answer: answer,
    route: route,
    crisisRow: crisisRow,
  ),
);

class _ReportDialog extends StatefulWidget {
  final QaService service;
  final String question;
  final String answer;
  final String route;
  final Widget? crisisRow;
  const _ReportDialog({
    required this.service,
    required this.question,
    required this.answer,
    required this.route,
    required this.crisisRow,
  });

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  QaReportReason? _reason;
  final _note = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    final t = AppLocalizations.of(context)!;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.service.report(
        QaReport(
          question: widget.question,
          answer: widget.answer,
          reason: reason,
          note: _note.text,
          lang: Localizations.localeOf(context).languageCode,
          route: widget.route,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final message = switch (e) {
        QaException(error: QaError.rateLimited) => t.qaReportRateLimited,
        QaException(error: QaError.reportDailyFull) =>
          kContactEmail.isEmpty
              ? t.qaReportDailyFull
              : t.qaReportDailyFullEmail(kContactEmail),
        _ => t.qaReportFailed,
      };
      setState(() {
        _sending = false;
        _error = message;
      });
      final view = View.maybeOf(context);
      if (view != null) {
        SemanticsService.sendAnnouncement(
          view,
          message,
          Directionality.of(context),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final reasons = [
      (QaReportReason.incorrect, t.qaReportReasonIncorrect),
      (QaReportReason.outdated, t.qaReportReasonOutdated),
      (QaReportReason.offensive, t.qaReportReasonOffensive),
      (QaReportReason.other, t.qaReportReasonOther),
    ];
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        title: Text(t.qaReport),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(t.qaReportReason, style: text.titleSmall),
            ),
            RadioGroup<QaReportReason>(
              groupValue: _reason,
              onChanged: (v) {
                if (!_sending) setState(() => _reason = v);
              },
              child: Column(
                children: [
                  for (final (value, label) in reasons)
                    RadioListTile<QaReportReason>(
                      value: value,
                      enabled: !_sending,
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: AppLayout.touchTarget,
                      title: Text(label, style: text.bodyMedium),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              enabled: !_sending,
              minLines: 2,
              maxLines: 4,
              maxLength: QaReport.maxNote,
              style: text.bodyMedium,
              decoration: InputDecoration(
                labelText: t.qaReportNote,
                border: const OutlineInputBorder(),
              ),
            ),
            Text(
              t.qaReportNotice,
              style: text.bodySmall!.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (_error case final e?) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  e,
                  style: text.bodyMedium!.copyWith(color: AppColors.attention),
                ),
              ),
            ],
            if (widget.crisisRow case final row?) ...[
              const SizedBox(height: 16),
              row,
            ],
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, AppLayout.touchTarget),
            ),
            onPressed: _sending ? null : () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, AppLayout.touchTarget),
            ),
            onPressed: _reason == null || _sending ? null : _send,
            child: _sending
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: t.qaReportSend,
                    ),
                  )
                : Text(t.qaReportSend),
          ),
        ],
      ),
    );
  }
}
