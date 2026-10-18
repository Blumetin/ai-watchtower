import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/qa_service.dart' show kContactEmail;
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../web/site_chrome.dart';

class AboutScreen extends StatelessWidget {
  final bool embedded;
  const AboutScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return sitePage(
      embedded: embedded,
      title: t.aboutUsTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.aboutBody1, style: text.bodyMedium),
                const SizedBox(height: 16),
                Text(t.aboutBody2, style: text.bodyMedium),
                const SizedBox(height: 16),
                Text(t.aboutBody3, style: text.bodyMedium),
                if (kIsWeb) ...[
                  const SizedBox(height: 16),
                  Text(t.pushWebUnavailable, style: text.bodyMedium),
                ],
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(t.aboutContact, style: text.titleMedium),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Symbols.mail_rounded,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: SelectableText(
                        kContactEmail,
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(t.aboutBuiltWithTitle, style: text.titleMedium),
                ),
                const SizedBox(height: 4),
                Text(t.aboutBuiltWithBody, style: text.bodyMedium),
                const SizedBox(height: 8),
                Text(
                  t.aboutTrademarks,
                  style: text.labelMedium!.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
