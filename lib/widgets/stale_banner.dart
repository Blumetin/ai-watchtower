import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/alert_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';

class StaleBanner extends StatelessWidget {
  final AlertFeed feed;
  final VoidCallback? onRetry;
  const StaleBanner({super.key, required this.feed, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppLayout.radius),
      ),
      child: Row(
        children: [
          const Icon(Symbols.cloud_off_rounded, color: AppColors.attention),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feed.failed ? t.updateFailed : t.staleData,
              style: text.bodySmall!.copyWith(color: AppColors.attention),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(t.retry)),
        ],
      ),
    );
  }
}
