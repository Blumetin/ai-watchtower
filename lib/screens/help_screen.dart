import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../widgets/call.dart';
import '../widgets/crisis_lines.dart';
import 'prep_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final emergency = [
      _CallTile(
        number: '119',
        label: t.fire119,
        color: AppColors.sevRed,
        icon: Symbols.local_fire_department_rounded,
      ),
      _CallTile(
        number: '110',
        label: t.police110,
        color: AppColors.primary,
        icon: Symbols.local_police_rounded,
      ),
    ];
    final line1990 = _CallTile(
      number: '1990',
      label: t.line1990,
      color: AppColors.tertiary,
      icon: Symbols.translate_rounded,
    );
    final support = [
      _CallTile(
        number: '1925',
        label: t.line1925,
        color: AppColors.tertiary,
        icon: Symbols.favorite_rounded,
      ),
      _CallTile(
        number: '1995',
        label: t.line1995,
        note: t.hoursVary,
        color: AppColors.tertiary,
        icon: Symbols.support_agent_rounded,
      ),
      _CallTile(
        number: '1980',
        label: t.line1980,
        note: t.hoursVary,
        color: AppColors.tertiary,
        icon: Symbols.forum_rounded,
      ),
    ];
    Widget heading(String s) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        header: true,
        child: Text(s, style: text.headlineMedium),
      ),
    );
    final local = switch (lang) {
      'ja' => [koryuOption(t)],
      _ => <DialOption>[],
    };
    return ListView(
      padding: AppLayout.pagePadding,
      children: [
        if (local.isNotEmpty) ...[
          heading(t.localHelpSection),
          for (final o in local)
            _CallTile(
              number: o.dial,
              display: o.display,
              label: o.label,
              note: o.notes.join('\n'),
              copy: o.copy,
              color: AppColors.tertiary,
              icon: Symbols.account_balance_rounded,
            ),
          line1990,
          const SizedBox(height: 24),
        ],
        heading(t.emergencySection),
        ...emergency,
        const SizedBox(height: 24),
        heading(t.supportSection),
        if (lang == 'en') line1990,
        ...support,
        const SizedBox(height: 24),
        heading(t.prepTitle),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppLayout.radius),
            side: const BorderSide(
              color: AppColors.cardBorder,
              width: AppLayout.borderWidth,
            ),
          ),
          child: ListTile(
            minTileHeight: 72,
            leading: const Icon(Symbols.backpack_rounded, size: 32),
            title: Text(t.prepTitle, style: text.titleMedium),
            subtitle: Text(t.prepEntryDesc, style: text.bodySmall),
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PrepScreen())),
          ),
        ),
      ],
    );
  }
}

class _CallTile extends StatelessWidget {
  final String number;

  final String? display;
  final String label;
  final Color color;
  final IconData icon;
  final String? note;

  final String? copy;
  const _CallTile({
    required this.number,
    this.display,
    required this.label,
    required this.color,
    required this.icon,
    this.note,
    this.copy,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radius),
          side: const BorderSide(
            color: AppColors.cardBorder,
            width: AppLayout.borderWidth,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppLayout.radius),
          onTap: () => callNumber(context, number),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color,
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          display ?? number,
                          style: text.headlineMedium!.copyWith(color: color),
                        ),
                      ),
                      Text(label, style: text.bodySmall),
                      if (note != null)
                        Text(
                          note!,
                          style: text.labelMedium!.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                Semantics(
                  label: t.tapToCall,
                  child: Icon(Symbols.call_rounded, color: color, size: 28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return copy == null
        ? tile
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tile,
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: CopyNumberButton(number: copy!),
              ),
            ],
          );
  }
}
