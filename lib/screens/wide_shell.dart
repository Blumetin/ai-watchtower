import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/alert.dart';
import '../data/alert_repository.dart';
import '../data/earthquake.dart';
import '../data/push_prefs.dart';
import '../data/push_service.dart';
import '../data/qa_service.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../web/site_chrome.dart';
import '../widgets/alert_group.dart';
import '../widgets/alert_opener.dart';
import 'about_screen.dart';
import 'alert_detail_screen.dart';
import 'help_screen.dart';
import 'home_screen.dart';
import 'prep_screen.dart';
import 'qa_screen.dart';
import 'quake_screen.dart';
import 'settings_screen.dart';

class WideAppShell extends StatefulWidget {
  final AlertRepository alerts;
  final EarthquakeRepository quakes;
  final QaService qa;
  final PushPrefsStore pushPrefs;
  final ValueChanged<Locale> onLocaleChanged;
  final SiteSection initialSection;
  final ValueChanged<SiteSection> onSectionChanged;
  const WideAppShell({
    super.key,
    required this.alerts,
    required this.quakes,
    required this.qa,
    required this.pushPrefs,
    required this.onLocaleChanged,
    required this.initialSection,
    required this.onSectionChanged,
  });

  @override
  State<WideAppShell> createState() => _WideAppShellState();
}

typedef _Group = ({
  List<Alert> alerts,
  ValueListenable<AlertFeed?>? feed,
  bool Function(Alert)? filter,
});

class _WideAppShellState extends State<WideAppShell> {
  static const _paneMode = PaneMode.slide;

  late SiteSection _section = widget.initialSection;
  late final _visited = <SiteSection>{_section};

  Alert? _alert;
  ValueListenable<AlertFeed?>? _feed;
  _Group? _group;

  _Group? _parentGroup;
  ({Earthquake quake, bool isSample})? _quake;

  ({Alert alert, ValueListenable<AlertFeed?> feed})? _top;

  final _quakeBack = FocusNode(debugLabel: 'quakeBack');

  final _alertBack = FocusNode(debugLabel: 'alertBack');

  void _focusAlertBack() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _alertBack.requestFocus();
  });

  @override
  void initState() {
    super.initState();
    PushService.instance.openUid.addListener(_openFromPush);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromPush());
  }

  @override
  void dispose() {
    PushService.instance.openUid.removeListener(_openFromPush);
    _quakeBack.dispose();
    _alertBack.dispose();
    super.dispose();
  }

  Future<void> _openFromPush() async {
    final uid = PushService.instance.openUid.value;
    if (uid == null || !mounted) return;
    PushService.instance.openUid.value = null;
    final t = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    Alert? a;
    try {
      a = await fetchAlertByUid(uid);
    } catch (e) {
      debugPrint('Push: open $uid failed: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(t.loadFailed),
            action: SnackBarAction(
              label: t.retry,
              onPressed: () => PushService.instance.openUid.value = uid,
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    if (a == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.pushAlertEnded)));
      return;
    }
    final alert = a;
    setState(() {
      _alert = alert;
      _feed = null;
      _group = null;
      _parentGroup = null;
    });
    _select(SiteSection.alerts);
    _focusAlertBack();
  }

  void _select(SiteSection s) {
    setState(() {
      _section = s;
      _visited.add(s);
    });
    widget.onSectionChanged(s);
  }

  bool get _hasDetail =>
      (_section == SiteSection.alerts && (_alert != null || _group != null)) ||
      (_section == SiteSection.quakes && _quake != null);

  void _back() {
    setState(() {
      if (_section == SiteSection.quakes && _quake != null) {
        _quake = null;
      } else if (_section == SiteSection.alerts && _alert != null) {
        _alert = null;
        _group = _parentGroup;
        _parentGroup = null;
      } else if (_section == SiteSection.alerts && _group != null) {
        _group = null;
      } else {
        _section = SiteSection.alerts;
        _visited.add(_section);
        widget.onSectionChanged(_section);
      }
    });
  }

  Widget _alertsPage(AppLocalizations t, TextTheme text) {
    final group = _group;
    final a = _alert;
    final top = _paneMode == PaneMode.auto && a == null && group == null
        ? _top
        : null;
    Widget detail() {
      if (group != null) {
        return AlertGroupScreen(
          key: ValueKey(group.alerts.first.uid),
          alerts: group.alerts,
          feed: group.feed,
          filter: group.filter,
          embedded: true,
        );
      }
      if (top != null) {
        return AlertDetailScreen(
          key: ValueKey(top.alert.uid),
          alert: top.alert,
          feed: top.feed,
          embedded: true,
        );
      }
      if (a == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              t.webSelectAlert,
              textAlign: TextAlign.center,
              style: text.bodyMedium!.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        );
      }
      return AlertDetailScreen(
        key: ValueKey(a.uid),
        alert: a,
        feed: _feed,
        embedded: true,
      );
    }

    return AlertOpener(
      open: (alert, feed) {
        setState(() {
          _alert = alert;
          _feed = feed;
          _parentGroup = _group;
          _group = null;
        });
        _focusAlertBack();
      },
      openGroup: (alerts, feed, filter) {
        setState(() {
          _group = (alerts: alerts, feed: feed, filter: filter);
          _alert = null;
          _parentGroup = null;
        });
        _focusAlertBack();
      },
      child: AlertsSplit(
        mode: _paneMode,
        hasDetail: a != null || group != null || top != null,
        list: HomeScreen(
          repository: widget.alerts,
          selectedUid: a?.uid ?? top?.alert.uid,
          onTopChanged: _paneMode != PaneMode.auto
              ? null
              : (t, feed) => setState(
                  () => _top = t == null ? null : (alert: t, feed: feed),
                ),
        ),
        detail: Column(
          key: ValueKey(
            group != null
                ? 'group:${group.alerts.first.uid}'
                : 'alert:${a?.uid ?? top?.alert.uid}',
          ),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (a != null && _parentGroup != null)
              SiteBackButton(
                focusNode: _alertBack,
                label: t.backToGroup,
                onPressed: () {
                  setState(() {
                    _alert = null;
                    _group = _parentGroup;
                    _parentGroup = null;
                  });
                  _focusAlertBack();
                },
              )
            else if (group != null || (a != null && _paneMode != PaneMode.auto))
              SiteBackButton(
                focusNode: _alertBack,
                close: true,
                label: MaterialLocalizations.of(context).closeButtonLabel,
                onPressed: () => setState(() {
                  _alert = null;
                  _group = null;
                  _parentGroup = null;
                }),
              ),
            Expanded(child: detail()),
          ],
        ),
      ),
    );
  }

  Widget _quakesPage(AppLocalizations t) {
    final q = _quake;
    return IndexedStack(
      index: q == null ? 0 : 1,
      children: [
        ExcludeFocus(
          excluding: q != null,
          child: QuakeScreen(
            repository: widget.quakes,
            onOpen: (quake, isSample) {
              setState(() => _quake = (quake: quake, isSample: isSample));
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _quakeBack.requestFocus();
              });
            },
          ),
        ),
        if (q == null)
          const SizedBox.shrink()
        else
          Column(
            key: ValueKey(q.quake.id ?? q.quake.originTime),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SiteBackButton(
                focusNode: _quakeBack,
                label: t.tabQuake,
                onPressed: () => setState(() => _quake = null),
              ),
              Expanded(
                child: QuakeDetailScreen(
                  quake: q.quake,
                  isSample: q.isSample,
                  embedded: true,
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    Widget page(SiteSection s) => switch (s) {
      SiteSection.alerts => _alertsPage(t, text),
      SiteSection.quakes => _quakesPage(t),
      SiteSection.ask => QaScreen(service: widget.qa),
      SiteSection.help => const HelpScreen(),
      SiteSection.prepare => const PrepScreen(embedded: true),
      SiteSection.sources => const DataSourcesScreen(embedded: true),
      SiteSection.privacy => const PrivacyScreen(embedded: true),
      SiteSection.about => const AboutScreen(embedded: true),
    };
    return PopScope(
      canPop: _section == SiteSection.alerts && !_hasDetail,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            SiteHeader(
              current: _section,
              isWide: true,
              onSelect: _select,
              onLocaleChanged: widget.onLocaleChanged,
              actions: [
                IconButton(
                  iconSize: siteHeaderIconSize(context),
                  tooltip: t.settingsTitle,
                  icon: const Icon(
                    Symbols.settings_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SettingsScreen(pushPrefs: widget.pushPrefs),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: siteMaxContent),
                  child: IndexedStack(
                    index: _section.index,
                    children: [
                      for (final s in SiteSection.values)
                        _visited.contains(s)
                            ? ExcludeFocus(
                                key: ValueKey(s),
                                excluding: s != _section,
                                child: page(s),
                              )
                            : SizedBox.shrink(key: ValueKey(s)),
                    ],
                  ),
                ),
              ),
            ),
            SiteFooter(onSelect: _select),
          ],
        ),
      ),
    );
  }
}
