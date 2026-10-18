import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import 'call.dart';

class CrisisLine {
  final String dial;

  final String short;

  final String label;

  final String semantics;
  final Color color;
  final IconData icon;
  final List<DialOption>? options;
  final String? optionsTitle;
  const CrisisLine(
    this.dial,
    this.short,
    this.label,
    this.semantics,
    this.color,
    this.icon, {
    this.options,
    this.optionsTitle,
  });
}

class DialOption {
  final String dial;
  final String display;
  final String label;
  final List<String> notes;

  final String? copy;
  const DialOption(
    this.dial,
    this.display,
    this.label,
    this.notes, {
    this.copy,
  });
}

class CopyNumberButton extends StatefulWidget {
  final String number;
  const CopyNumberButton({super.key, required this.number});

  @override
  State<CopyNumberButton> createState() => _CopyNumberButtonState();
}

class _CopyNumberButtonState extends State<CopyNumberButton> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.number));
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final style = Theme.of(context).textTheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.centerLeft,
            minimumSize: const Size(0, AppLayout.touchTarget),
          ),
          onPressed: _copy,
          icon: const Icon(Symbols.content_copy_rounded, size: 18),
          label: Text(t.copyNumber(widget.number)),
        ),
        if (_copied)
          Semantics(
            liveRegion: true,
            child: Text(
              t.copiedNumber(widget.number),
              style: style.labelMedium!.copyWith(color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}

DialOption koryuOption(AppLocalizations t) => DialOption(
  '+886227138000',
  '+886-2-2713-8000',
  t.lineKoryu,
  [t.koryuHours, t.koryuDomestic],
);

List<CrisisLine> crisisLines(AppLocalizations t, String lang) {
  final fire = CrisisLine(
    '119',
    t.row119,
    t.crisisCall119,
    t.dialSemantics(t.crisisCall119),
    AppColors.sevRed,
    Symbols.call_rounded,
  );
  final l1925 = CrisisLine(
    '1925',
    t.row1925,
    t.call1925,
    t.dialSemantics(t.call1925),
    AppColors.tertiary,
    Symbols.favorite_rounded,
  );
  final l1990 = CrisisLine(
    '1990',
    t.row1990,
    t.call1990,
    t.dialSemantics(t.call1990),
    AppColors.tertiary,
    Symbols.translate_rounded,
  );
  return switch (lang) {
    'zh' => [fire, l1925],
    'ja' => [
      fire,
      CrisisLine(
        koryuOption(t).dial,
        t.koryuShort,
        t.koryuShort,
        t.callKoryu,
        AppColors.tertiary,
        Symbols.account_balance_rounded,
      ),
      l1990,
      l1925,
    ],
    _ => [fire, l1990, l1925],
  };
}

Future<void> dialLine(BuildContext context, CrisisLine line) async {
  final options = line.options;
  if (options == null) return callNumber(context, line.dial);
  final t = AppLocalizations.of(context)!;
  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final text = Theme.of(ctx).textTheme;
      return AlertDialog(
        title: Text(line.optionsTitle ?? line.label),
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final o in options) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppLayout.radius),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppLayout.radius),
                      onTap: () => Navigator.of(ctx).pop(o.dial),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: AppLayout.touchTarget,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(o.label, style: text.titleMedium),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        o.display,
                                        style: text.titleMedium!.copyWith(
                                          color: AppColors.tertiary,
                                        ),
                                      ),
                                    ),
                                    for (final n in o.notes)
                                      Text(
                                        n,
                                        style: text.labelMedium!.copyWith(
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Semantics(
                                label: t.tapToCall,
                                child: const Icon(
                                  Symbols.call_rounded,
                                  color: AppColors.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (o.copy case final c?)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: CopyNumberButton(number: c),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, AppLayout.touchTarget),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.closeLabel),
          ),
        ],
      );
    },
  );
  if (picked != null && context.mounted) await callNumber(context, picked);
}
