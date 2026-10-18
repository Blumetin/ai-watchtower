import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

Future<void> callNumber(BuildContext context, String number) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final t = AppLocalizations.of(context)!;
  bool ok;
  try {
    ok = await launchUrl(Uri(scheme: 'tel', path: number));
  } catch (_) {
    ok = false;
  }
  if (ok && !kIsWeb) return;
  if (messenger == null || !messenger.mounted) return;
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 15),
      content: Text(ok ? t.callManual(number) : t.callFailed(number)),
      action: SnackBarAction(
        label: t.copy,
        onPressed: () =>
            Clipboard.setData(ClipboardData(text: number))
                .catchError((Object _) {}),
      ),
    ),
  );
}

Future<void> openExternal(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final t = AppLocalizations.of(context)!;
  final uri = Uri.tryParse(url);
  var ok = false;
  if (uri != null && uri.scheme == 'https' && uri.host.isNotEmpty) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok && messenger != null && messenger.mounted) {
    messenger.showSnackBar(SnackBar(content: Text(t.openLinkFailed)));
  }
}
