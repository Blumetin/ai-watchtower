import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';
import '../main.dart' show appLanguages, zhTW;
import '../theme.dart';

enum SiteSection { alerts, quakes, ask, help, prepare, sources, privacy, about }

const siteMaxContent = 1200.0;
const siteWide = 840.0;

List<(SiteSection, String, IconData)> siteNavItems(AppLocalizations t) => [
  (SiteSection.alerts, t.tabAlerts, Symbols.notifications_active_rounded),
  (SiteSection.quakes, t.tabQuake, Symbols.earthquake_rounded),
  (SiteSection.ask, t.tabQa, Symbols.support_agent_rounded),
  (SiteSection.help, t.tabHelp, Symbols.call_rounded),
  (SiteSection.prepare, t.prepTitle, Symbols.backpack_rounded),
];

typedef _HeaderSize = ({
  double height,
  double brandIcon,
  double brandText,
  double navText,
  double icon,
});

_HeaderSize _headerSize(double width) => width >= 1200
    ? (height: 72, brandIcon: 30, brandText: 22, navText: 18, icon: 28)
    : width >= 600
    ? (height: 68, brandIcon: 27, brandText: 20, navText: 17, icon: 26)
    : (height: 64, brandIcon: 24, brandText: 18, navText: 16, icon: 24);

bool sitePhoneLandscape(BuildContext context) {
  if (!kIsWeb) return false;
  final touch =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  final size = MediaQuery.sizeOf(context);
  return touch && size.shortestSide < 600 && size.width > size.height;
}

_HeaderSize _headerSizeOf(BuildContext context) => sitePhoneLandscape(context)
    ? (height: 48, brandIcon: 22, brandText: 17, navText: 15, icon: 24)
    : _headerSize(MediaQuery.sizeOf(context).width);

double siteHeaderIconSize(BuildContext context) => _headerSizeOf(context).icon;

class SiteHeader extends StatelessWidget {
  final SiteSection current;
  final bool isWide;
  final ValueChanged<SiteSection> onSelect;
  final ValueChanged<Locale> onLocaleChanged;

  final List<Widget> actions;
  const SiteHeader({
    super.key,
    required this.current,
    required this.isWide,
    required this.onSelect,
    required this.onLocaleChanged,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final size = _headerSizeOf(context);
    final compact = sitePhoneLandscape(context);
    return Material(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: siteMaxContent),
            child: SizedBox(
              height: size.height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Semantics(
                      link: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onSelect(SiteSection.alerts),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: compact ? 4 : 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Symbols.notifications_active_rounded,
                                color: Colors.white,
                                fill: 1,
                                size: size.brandIcon,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                t.appTitle,
                                overflow: TextOverflow.ellipsis,
                                style: text.headlineSmall!.copyWith(
                                  color: Colors.white,
                                  fontSize: size.brandText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: isWide
                          ? LayoutBuilder(
                              builder: (context, c) => SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: c.maxWidth,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      for (final (s, label, _) in siteNavItems(
                                        t,
                                      ))
                                        _NavLink(
                                          fontSize: size.navText,
                                          label: label,
                                          selected: s == current,
                                          onTap: () => onSelect(s),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                    ...actions,
                    if (!isWide)
                      Builder(
                        builder: (context) => IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .openAppDrawerTooltip,
                          iconSize: size.icon,
                          icon: const Icon(
                            Symbols.menu_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Scaffold.of(context).openEndDrawer(),
                        ),
                      ),
                    _LanguageMenu(
                      onLocaleChanged: onLocaleChanged,
                      iconSize: size.icon,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final double fontSize;
  final bool selected;
  final VoidCallback onTap;
  const _NavLink({
    required this.fontSize,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      child: TextButton(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14),
          ),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          overlayColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            style: text.titleMedium!.copyWith(
              fontSize: fontSize,
              color: Colors.white,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  final ValueChanged<Locale> onLocaleChanged;
  final double iconSize;
  const _LanguageMenu({required this.onLocaleChanged, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    return PopupMenuButton<String>(
      tooltip: t.languageTitle,
      iconSize: iconSize,
      icon: const Icon(Symbols.language_rounded, color: Colors.white),
      onSelected: (code) => onLocaleChanged(code == 'zh' ? zhTW : Locale(code)),
      itemBuilder: (_) => [
        for (final (code, name, beta) in appLanguages)
          PopupMenuItem(
            value: code,
            height: AppLayout.touchTarget,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: code == lang
                      ? const Icon(Symbols.check_rounded, size: 20)
                      : null,
                ),
                Text(name),
                if (beta) ...[
                  const SizedBox(width: 8),
                  Text(
                    t.languageBeta,
                    style: Theme.of(context).textTheme.labelMedium!
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class SiteNavDrawer extends StatelessWidget {
  final SiteSection current;
  final ValueChanged<SiteSection> onSelect;
  const SiteNavDrawer({
    super.key,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            for (final (s, label, icon) in siteNavItems(t))
              ListTile(
                minTileHeight: AppLayout.touchTarget,
                leading: Icon(icon),
                title: Text(label, style: text.titleMedium),
                selected: s == current,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelect(s);
                },
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SiteFooterBody(onSelect: onSelect),
            ),
          ],
        ),
      ),
    );
  }
}

class SiteFooter extends StatelessWidget {
  final ValueChanged<SiteSection> onSelect;
  const SiteFooter({super.key, required this.onSelect});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: AppColors.surfaceContainer,
      border: Border(top: BorderSide(color: AppColors.outlineVariant)),
    ),
    child: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: siteMaxContent),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: SiteFooterBody(onSelect: onSelect, centered: true),
          ),
        ),
      ),
    ),
  );
}

class SiteFooterBody extends StatelessWidget {
  final ValueChanged<SiteSection> onSelect;

  final bool centered;
  const SiteFooterBody({
    super.key,
    required this.onSelect,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    Widget link(String label, SiteSection s) => TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: () {
        Scaffold.maybeOf(context)?.closeEndDrawer();
        onSelect(s);
      },
      child: Text(label),
    );
    final links = [
      link(t.aboutUsTitle, SiteSection.about),
      link(t.dataSourcesTitle, SiteSection.sources),
      link(t.privacyTitle, SiteSection.privacy),
    ];
    final Widget row = kIsWeb && !centered
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: links,
          )
        : Wrap(
            spacing: 8,
            alignment: centered ? WrapAlignment.center : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: links,
          );
    if (!kIsWeb) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Text(
            t.recaptchaNotice,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class SitePageTitle extends StatelessWidget {
  final String title;
  const SitePageTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final compact = sitePhoneLandscape(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(24, 0, 24, 4)
          : const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: compact ? text.titleMedium : text.headlineSmall,
        ),
      ),
    );
  }
}

Widget sitePage({
  required bool embedded,
  required String title,
  required Widget body,
}) => embedded
    ? Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SitePageTitle(title),
          Expanded(child: body),
        ],
      )
    : Scaffold(
        appBar: AppBar(title: Text(title)),
        body: body,
      );

class SiteBackButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  final bool close;
  const SiteBackButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.focusNode,
    this.close = false,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      focusNode: focusNode,
      autofocus: true,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, AppLayout.touchTarget),
      ),
      onPressed: onPressed,
      icon: Icon(close ? Symbols.close_rounded : Symbols.arrow_back_rounded),
      label: Text(label),
    ),
  );
}

enum PaneMode {
  auto,
  slide;

  static PaneMode parse(String? v) => v == 'auto' ? auto : slide;
}

class AlertsSplit extends StatefulWidget {
  final Widget list;
  final Widget detail;

  final bool hasDetail;
  final PaneMode mode;
  const AlertsSplit({
    super.key,
    required this.list,
    required this.detail,
    required this.hasDetail,
    required this.mode,
  });

  @override
  State<AlertsSplit> createState() => _AlertsSplitState();
}

class _AlertsSplitState extends State<AlertsSplit> {
  static const _duration = Duration(milliseconds: 280);

  Widget? _closing;

  @override
  void didUpdateWidget(AlertsSplit old) {
    super.didUpdateWidget(old);
    final closing = widget.mode == PaneMode.slide && !widget.hasDetail;
    if (!closing) {
      _closing = null;
    } else if (old.hasDetail) {
      _closing = old.detail;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AlertsSplit(:list, :hasDetail, :mode) = widget;
    final detail = hasDetail ? widget.detail : (_closing ?? widget.detail);
    final listWidth = (MediaQuery.sizeOf(context).width * 0.4).clamp(
      360.0,
      440.0,
    );
    const divider = VerticalDivider(width: 1, color: AppColors.outlineVariant);
    if (mode == PaneMode.auto) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: listWidth, child: list),
          divider,
          Expanded(child: detail),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final open = hasDetail;
        final paneWidth = c.maxWidth - listWidth;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: _duration,
              curve: Curves.easeOutCubic,
              left: 0,
              top: 0,
              bottom: 0,
              width: open ? listWidth : c.maxWidth,
              child: list,
            ),
            AnimatedPositioned(
              duration: _duration,
              curve: Curves.easeOutCubic,
              left: open ? listWidth : c.maxWidth,
              top: 0,
              bottom: 0,
              width: paneWidth,
              onEnd: () {
                if (mounted && !widget.hasDetail && _closing != null) {
                  setState(() => _closing = null);
                }
              },
              child: IgnorePointer(
                ignoring: !open,
                child: TickerMode(
                  enabled: open,
                  child: ExcludeFocus(
                    excluding: !open,
                    child: ExcludeSemantics(
                      excluding: !open,
                      child: Material(
                        color: AppColors.surface,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            divider,
                            Expanded(child: detail),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
