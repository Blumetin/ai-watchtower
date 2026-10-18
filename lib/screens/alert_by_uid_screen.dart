import 'package:flutter/material.dart';

import '../data/alert.dart';
import '../data/alert_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'alert_detail_screen.dart';

class AlertByUidScreen extends StatefulWidget {
  final String uid;
  const AlertByUidScreen({super.key, required this.uid});

  @override
  State<AlertByUidScreen> createState() => _AlertByUidScreenState();
}

class _AlertByUidScreenState extends State<AlertByUidScreen> {
  late Future<Alert?> _alert = fetchAlertByUid(widget.uid);

  @override
  void didUpdateWidget(AlertByUidScreen old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid) _alert = fetchAlertByUid(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return FutureBuilder<Alert?>(
      future: _alert,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.hasData) {
          return AlertDetailScreen(alert: snap.data!);
        }
        final Widget body;
        if (snap.connectionState != ConnectionState.done) {
          body = const Center(child: CircularProgressIndicator());
        } else if (snap.hasError) {
          body = Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.loadFailed, style: text.bodyMedium),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      setState(() => _alert = fetchAlertByUid(widget.uid)),
                  child: Text(t.retry),
                ),
              ],
            ),
          );
        } else {
          body = Center(
            child: Padding(
              padding: AppLayout.pagePadding,
              child: Text(
                t.pushAlertEnded,
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(t.alertDetail)),
          body: body,
        );
      },
    );
  }
}
