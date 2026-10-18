import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../data/alert.dart';
import '../data/alert_repository.dart';
import '../data/earthquake.dart';
import '../data/qa_service.dart';
import '../l10n/app_localizations.dart';
import '../main.dart' show firebaseReady, supportedLocales, zhTW;
import '../screens/about_screen.dart';
import '../screens/alert_detail_screen.dart';
import '../screens/help_screen.dart';
import '../screens/home_screen.dart';
import '../screens/prep_screen.dart';
import '../screens/qa_screen.dart';
import '../screens/quake_screen.dart';
import '../screens/settings_screen.dart' show DataSourcesScreen, PrivacyScreen;
import '../theme.dart';
import '../widgets/alert_group.dart';
import '../widgets/alert_opener.dart';
import 'browser_history.dart';
import 'site_chrome.dart';
import 'web_lang.dart';

class WebApp extends StatefulWidget {
  const WebApp({super.key});

  @override
  State<WebApp> createState() => _WebAppState();
}

const _sectionPaths = {
  SiteSection.alerts: '/alerts',
  SiteSection.quakes: '/quakes',
  SiteSection.ask: '/ask',
  SiteSection.help: '/help',
  SiteSection.prepare: '/prepare',
  SiteSection.sources: '/sources',
  SiteSection.privacy: '/privacy',
  SiteSection.about: '/about',
};

class _WebAppState extends State<WebApp> {
  Locale? _locale = switch (startupWebLang()) {
    'zh' => zhTW,
    final code? => Locale(code),
    null => null,
  };

  @override
  void initState() {
    super.initState();
    loadWebRestore();
  }

  final AlertRepository _alerts = firebaseReady
      ? FirestoreAlertRepository()
      : const UnavailableAlertRepository();
  final EarthquakeRepository _quakes = firebaseReady
      ? FirestoreEarthquakeRepository()
      : const UnavailableEarthquakeRepository();
  final QaService _qa = firebaseReady
      ? CallableQaService()
      : const UnavailableQaService();

  static final String? _initialPane =
      switch (Uri.base.queryParameters['pane']) {
        final v? when v == 'slide' || v == 'auto' => v,
        _ => null,
      };

  late final GoRouter _router = GoRouter(
    initialLocation: '/alerts',
    onException: (_, _, router) => router.go('/alerts'),
    redirect: (_, state) {
      final pane = _initialPane;
      final q = state.uri.queryParameters;
      if (pane == null || q.containsKey('pane')) return null;
      return state.uri
          .replace(queryParameters: {...q, 'pane': pane})
          .toString();
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/alerts'),
      ShellRoute(
        builder: (context, state, child) => _WebShell(
          path: state.uri.path,
          paneMode: PaneMode.parse(state.uri.queryParameters['pane']),
          alerts: _alerts,
          quakes: _quakes,
          qa: _qa,
          onLocaleChanged: (l) {
            setState(() => _locale = l);
            saveWebLang(l.languageCode);
          },
          child: child,
        ),
        routes: [
          for (final path in _sectionPaths.values)
            GoRoute(path: path, pageBuilder: _blank),
          GoRoute(path: '/alerts/:id', pageBuilder: _blank),
          GoRoute(path: '/quakes/:id', pageBuilder: _blank),
        ],
      ),
    ],
  );

  static Page<void> _blank(BuildContext _, GoRouterState state) =>
      NoTransitionPage(key: state.pageKey, child: const SizedBox.shrink());

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    onGenerateTitle: (c) => AppLocalizations.of(c)!.appTitle,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    locale: _locale,
    supportedLocales: supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: _router,
  );
}

String _uidToPath(String uid) => uid.replaceAll('#', '~');
String _uidFromPath(String p) => p.replaceAll('~', '#');

class _WebShell extends StatefulWidget {
  final String path;
  final Widget child;
  final AlertRepository alerts;
  final EarthquakeRepository quakes;
  final QaService qa;
  final ValueChanged<Locale> onLocaleChanged;
  final PaneMode paneMode;
  const _WebShell({
    required this.path,
    required this.paneMode,
    required this.child,
    required this.alerts,
    required this.quakes,
    required this.qa,
    required this.onLocaleChanged,
  });

  @override
  State<_WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<_WebShell> {
  final _visited = <SiteSection>{};

  @override
  void initState() {
    super.initState();
    _visited.add(_section);
  }

  @override
  void didUpdateWidget(_WebShell old) {
    super.didUpdateWidget(old);
    _visited.add(_section);
  }

  String get path => widget.path;

  SiteSection get _section => SiteSection.values.firstWhere(
    (s) => path.startsWith(_sectionPaths[s]!),
    orElse: () => SiteSection.alerts,
  );

  static final _uidPattern = RegExp(r'^[A-Za-z0-9_.#-]+$');

  static final _quakeIdPattern = RegExp(r'^([0-9]{1,12}|L-[0-9]{8}T[0-9]{6})$');

  String? _idFor(String section, RegExp pattern, {bool uid = false}) {
    final parts = Uri.parse(path).pathSegments;
    if (parts.length != 2 || parts[0] != section) return null;
    final id = uid ? _uidFromPath(parts[1]) : parts[1];
    return pattern.hasMatch(id) ? id : '';
  }

  void _go(SiteSection s) => context.go(_sectionPaths[s]!);

  @override
  Widget build(BuildContext context) {
    final isWide =
        MediaQuery.sizeOf(context).width >= siteWide &&
        !sitePhoneLandscape(context);
    final section = _section;
    Widget page(SiteSection s) => switch (s) {
      SiteSection.alerts => _AlertsPage(
        repository: widget.alerts,
        selectedId: _idFor('alerts', _uidPattern, uid: true),
        isWide: isWide,
        paneMode: widget.paneMode,
        footer: SiteFooterBody(onSelect: _go),
      ),
      SiteSection.quakes => _QuakesPage(
        repository: widget.quakes,
        selectedId: _idFor('quakes', _quakeIdPattern),
      ),
      SiteSection.ask => QaScreen(service: widget.qa),
      SiteSection.help => const HelpScreen(),
      SiteSection.prepare => const PrepScreen(embedded: true),
      SiteSection.sources => const DataSourcesScreen(embedded: true),
      SiteSection.privacy => const PrivacyScreen(embedded: true),
      SiteSection.about => const AboutScreen(embedded: true),
    };
    return Scaffold(
      backgroundColor: AppColors.surface,
      endDrawer: isWide ? null : SiteNavDrawer(current: section, onSelect: _go),
      body: Column(
        children: [
          SiteHeader(
            current: section,
            isWide: isWide,
            onSelect: _go,
            onLocaleChanged: widget.onLocaleChanged,
          ),
          Expanded(
            child: Stack(
              children: [
                Offstage(child: widget.child),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: siteMaxContent),
                    child: IndexedStack(
                      index: section.index,
                      children: [
                        for (final s in SiteSection.values)
                          _visited.contains(s)
                              ? ExcludeFocus(
                                  key: ValueKey(s),
                                  excluding: s != section,
                                  child: SelectionArea(child: page(s)),
                                )
                              : SizedBox.shrink(key: ValueKey(s)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isWide) SiteFooter(onSelect: _go),
        ],
      ),
    );
  }
}

class _AlertsPage extends StatefulWidget {
  final AlertRepository repository;
  final String? selectedId;
  final bool isWide;
  final PaneMode paneMode;
  final Widget footer;
  const _AlertsPage({
    required this.repository,
    required this.selectedId,
    required this.isWide,
    required this.paneMode,
    required this.footer,
  });

  @override
  State<_AlertsPage> createState() => _AlertsPageState();
}

typedef _Group = ({
  List<Alert> alerts,
  ValueListenable<AlertFeed?>? feed,
  bool Function(Alert)? filter,
});

class _AlertsPageState extends State<_AlertsPage> {
  Alert? _selected;
  ValueListenable<AlertFeed?>? _feed;
  bool _notFound = false;
  _Group? _group;

  _Group? _parentGroup;

  bool _openedFromList = false;

  ({Alert alert, ValueListenable<AlertFeed?> feed})? _top;

  final _backFocus = FocusNode(debugLabel: 'alertBack');

  @override
  void dispose() {
    _backFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_AlertsPage old) {
    super.didUpdateWidget(old);
    if (old.isWide != widget.isWide || old.paneMode != widget.paneMode) {
      _top = null;
    }
    if (old.selectedId != widget.selectedId) {
      _sync();
      if (widget.selectedId != null) _focusBack();
    }
  }

  void _focusBack() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _backFocus.requestFocus();
    });
  }

  Future<void> _sync() async {
    final id = widget.selectedId;
    if (id == null) {
      _selected = null;
      _feed = null;
      _openedFromList = false;
      if (_parentGroup != null) {
        _group = _parentGroup;
        _parentGroup = null;
        _focusBack();
      }
      return;
    }
    if (_selected?.uid == id) return;
    setState(() => _notFound = false);
    if (!firebaseReady || id.isEmpty) return setState(() => _notFound = true);
    try {
      final a = await fetchAlertByUid(id);
      if (!mounted || widget.selectedId != id) return;
      setState(() {
        if (a == null) {
          _notFound = true;
        } else {
          _selected = a;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _notFound = true);
    }
  }

  void _open(Alert a, ValueListenable<AlertFeed?>? feed) {
    setState(() {
      _selected = a;
      _feed = feed;
      _parentGroup = _group;
      _group = null;
      _openedFromList = true;
    });
    context.go('/alerts/${_uidToPath(a.uid)}');
  }

  void _openGroup(
    List<Alert> alerts,
    ValueListenable<AlertFeed?>? feed,
    bool Function(Alert)? filter,
  ) {
    setState(() {
      _group = (alerts: alerts, feed: feed, filter: filter);
      _parentGroup = null;
    });
    if (widget.selectedId != null) context.go('/alerts');
    _focusBack();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final id = widget.selectedId;
    final group = id == null ? _group : null;
    final auto = widget.isWide && widget.paneMode == PaneMode.auto;
    final top = auto && id == null && group == null ? _top : null;
    final list = HomeScreen(
      repository: widget.repository,
      selectedUid: id ?? top?.alert.uid,
      onTopChanged: auto
          ? (a, feed) =>
                setState(() => _top = a == null ? null : (alert: a, feed: feed))
          : null,
      footer: widget.isWide ? null : widget.footer,
    );
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
      if (id == null) {
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
      final a = _selected;
      if (a == null || a.uid != id) {
        return Center(
          child: _notFound
              ? Text(t.alertNoLongerActive, style: text.bodyMedium)
              : const CircularProgressIndicator(),
        );
      }
      return AlertDetailScreen(
        key: ValueKey(a.uid),
        alert: a,
        feed: _feed,
        embedded: true,
      );
    }

    Widget body;
    if (widget.isWide) {
      body = AlertsSplit(
        mode: widget.paneMode,
        list: list,
        hasDetail: id != null || group != null || top != null,
        detail: Column(
          key: ValueKey(
            group != null
                ? 'group:${group.alerts.first.uid}'
                : 'alert:${id ?? top?.alert.uid}',
          ),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (id != null && _parentGroup != null)
              SiteBackButton(
                focusNode: _backFocus,
                label: t.backToGroup,
                onPressed: () =>
                    _openedFromList ? browserBack() : context.go('/alerts'),
              )
            else if (group != null || (id != null && !auto))
              SiteBackButton(
                focusNode: _backFocus,
                close: true,
                label: MaterialLocalizations.of(context).closeButtonLabel,
                onPressed: () {
                  setState(() {
                    _group = null;
                    _parentGroup = null;
                  });
                  if (id != null) {
                    _openedFromList ? browserBack() : context.go('/alerts');
                  }
                },
              ),
            Expanded(child: detail()),
          ],
        ),
      );
    } else {
      final showDetail = id != null || group != null;
      body = IndexedStack(
        index: showDetail ? 1 : 0,
        children: [
          ExcludeFocus(excluding: showDetail, child: list),
          ExcludeFocus(
            excluding: !showDetail,
            child: Column(
              key: ValueKey(
                group != null ? 'group:${group.alerts.first.uid}' : 'alert:$id',
              ),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SiteBackButton(
                  focusNode: _backFocus,
                  label: _parentGroup != null && id != null
                      ? t.backToGroup
                      : t.tabAlerts,
                  onPressed: () {
                    if (group != null) return setState(() => _group = null);
                    _openedFromList ? browserBack() : context.go('/alerts');
                  },
                ),
                Expanded(child: detail()),
              ],
            ),
          ),
        ],
      );
    }
    return AlertOpener(open: _open, openGroup: _openGroup, child: body);
  }
}


class _QuakesPage extends StatefulWidget {
  final EarthquakeRepository repository;
  final String? selectedId;
  const _QuakesPage({required this.repository, required this.selectedId});

  @override
  State<_QuakesPage> createState() => _QuakesPageState();
}

class _QuakesPageState extends State<_QuakesPage> {
  Earthquake? _selected;
  bool _isSample = false;
  bool _notFound = false;
  bool _openedFromList = false;
  final _backFocus = FocusNode(debugLabel: 'quakeBack');

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void dispose() {
    _backFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_QuakesPage old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) {
      _sync();
      if (widget.selectedId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _backFocus.requestFocus();
        });
      }
    }
  }

  Future<void> _sync() async {
    final id = widget.selectedId;
    if (id == null) {
      _selected = null;
      _openedFromList = false;
      _notFound = false;
      return;
    }
    if (_selected?.id == id) return;
    if (!firebaseReady || id.isEmpty) {
      setState(() {
        _selected = null;
        _notFound = true;
      });
      return;
    }
    setState(() => _notFound = false);
    try {
      final d = await FirebaseFirestore.instance.doc('earthquakes/$id').get();
      if (!mounted || widget.selectedId != id) return;
      final m = d.data();
      setState(() {
        final q = m == null ? null : Earthquake.fromMap(m, id: d.id);
        if (q == null || !q.complete) {
          _selected = null;
          _notFound = true;
        } else {
          _selected = q;
          _isSample = false;
        }
      });
    } catch (_) {
      if (!mounted || widget.selectedId != id) return;
      setState(() {
        _selected = null;
        _notFound = true;
      });
    }
  }

  void _open(Earthquake q, bool isSample) {
    final id = q.id;
    if (id == null || id.isEmpty) return;
    setState(() {
      _selected = q;
      _isSample = isSample;
      _notFound = false;
      _openedFromList = true;
    });
    context.go('/quakes/$id');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final id = widget.selectedId;
    final q = _selected;
    Widget detail() {
      if (q == null || q.id != id) {
        return Center(
          child: _notFound
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(t.loadFailed, style: text.bodyMedium),
                )
              : const CircularProgressIndicator(),
        );
      }
      return QuakeDetailScreen(
        key: ValueKey(q.id),
        quake: q,
        isSample: _isSample,
        embedded: true,
      );
    }

    final showDetail = id != null;
    return IndexedStack(
      index: showDetail ? 1 : 0,
      children: [
        ExcludeFocus(
          excluding: showDetail,
          child: QuakeScreen(repository: widget.repository, onOpen: _open),
        ),
        ExcludeFocus(
          excluding: !showDetail,
          child: Column(
            key: ValueKey(id),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SiteBackButton(
                focusNode: _backFocus,
                label: t.tabQuake,
                onPressed: () =>
                    _openedFromList ? browserBack() : context.go('/quakes'),
              ),
              Expanded(child: detail()),
            ],
          ),
        ),
      ],
    );
  }
}
