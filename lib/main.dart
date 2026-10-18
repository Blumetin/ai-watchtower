import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'data/alert_repository.dart';
import 'data/app_check_keeper.dart';
import 'data/demo_scenario.dart';
import 'data/earthquake.dart';
import 'data/push_prefs.dart';
import 'data/push_service.dart';
import 'data/qa_service.dart';
import 'data/web_resume.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'screens/alert_by_uid_screen.dart';
import 'screens/help_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/qa_screen.dart';
import 'screens/quake_screen.dart';
import 'theme.dart';
import 'screens/wide_shell.dart';
import 'web/site_chrome.dart' show SiteSection, siteWide;
import 'web/web_app.dart';
import 'widgets/splash_overlay.dart';

bool firebaseReady = false;

final bool firebasePlatform =
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

void _registerLicenses() {
  const fonts = {
    'Plus Jakarta Sans': 'PlusJakartaSans',
    'Atkinson Hyperlegible Next': 'AtkinsonHyperlegibleNext',
    'Noto Sans TC': 'NotoSansTC',
    'Noto Sans JP': 'NotoSansJP',
  };
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: name, value: file) in fonts.entries) {
      final text = await rootBundle.loadString('assets/fonts/OFL-$file.txt');
      yield LicenseEntryWithLineBreaks([name], text);
    }
    yield const LicenseEntryWithLineBreaks(
      ['內政部國土測繪中心 直轄市、縣市界線'],
      '提供機關：內政部國土測繪中心\n'
      '資料名稱：直轄市、縣市界線(TWD97經緯度)（版本 1140318，2025 年）\n'
      '資料集：https://data.gov.tw/dataset/7442\n'
      '本 App 將其簡化後用於示警詳情頁的縣市地圖。\n'
      '依政府資料開放授權條款－第 1 版提供：https://data.gov.tw/license',
    );
  });
}




const _appCheckSiteKey = String.fromEnvironment('APP_CHECK_SITE_KEY');
const _appCheckEnterprise = bool.fromEnvironment(
  'APP_CHECK_ENTERPRISE',
  defaultValue: true,
);


const _appCheckAndroidDebug =
    !kReleaseMode &&
    (kDebugMode || bool.fromEnvironment('APP_CHECK_ANDROID_DEBUG'));




const _appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');


WebProvider _webProvider() {
  if (_appCheckSiteKey.isEmpty) return WebDebugProvider();
  if (_appCheckEnterprise) return ReCaptchaEnterpriseProvider(_appCheckSiteKey);
  return ReCaptchaV3Provider(_appCheckSiteKey);
}


Future<bool> _activateAppCheck() async {
  
  if (kIsWeb && _appCheckSiteKey.isEmpty && !kDebugMode) {
    debugPrint('App Check: APP_CHECK_SITE_KEY missing, not activated on web');
    return false;
  }
  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: kIsWeb ? _webProvider() : null,
      providerAndroid: _appCheckAndroidDebug
          ? const AndroidDebugProvider(
              debugToken: _appCheckDebugToken == ''
                  ? null
                  : _appCheckDebugToken,
            )
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider(
              debugToken: _appCheckDebugToken == ''
                  ? null
                  : _appCheckDebugToken,
            )
          : const AppleAppAttestProvider(),
    );
    try {
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
    } catch (e) {
      debugPrint('App Check: setTokenAutoRefreshEnabled failed: $e');
    }
    return true;
  } catch (e) {
    debugPrint('App Check activate failed: $e');
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerLicenses();
  await initializeDateFormatting();
  
  if (firebasePlatform) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final appCheck = await _activateAppCheck();
      firebaseReady = true;
      if (kIsWeb && appCheck) WebResumeRefresher.start();
      if (!kIsWeb && appCheck) AppCheckKeeper.start();
      await PushService.instance.init();
    } catch (e) {
      debugPrint('Firebase init failed: $e');
    }
  }
  
  if (kIsWeb) {
    usePathUrlStrategy();
    runApp(const WebApp());
    return;
  }
  
  if (defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  runApp(const WatchtowerApp());
}


const _splashEnabled = true;

class WatchtowerApp extends StatefulWidget {
  const WatchtowerApp({super.key});

  @override
  State<WatchtowerApp> createState() => _WatchtowerAppState();
}


const zhTW = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hant',
  countryCode: 'TW',
);


const supportedLocales = [Locale('en'), zhTW, Locale('ja')];

class _WatchtowerAppState extends State<WatchtowerApp> {
  
  Locale? _locale;

  
  bool _splash = _splashEnabled && PushService.instance.openUid.value == null;

  @override
  Widget build(BuildContext context) => MaterialApp(
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
    home: RootShell(onLocaleChanged: (l) => setState(() => _locale = l)),
    builder: (context, child) => Stack(
      children: [
        _systemSafeArea(
          Builder(
            builder: (context) => withDemoScenarioNotice(context, child!),
          ),
        ),
        if (_splash)
          SplashOverlay(onDone: () => setState(() => _splash = false)),
      ],
    ),
  );
}




Widget _systemSafeArea(Widget child) =>
    defaultTargetPlatform == TargetPlatform.android
    ? ColoredBox(
        color: AppColors.surfaceContainer,
        child: SafeArea(top: false, child: child),
      )
    : child;



const appLanguages = [
  ('zh', '繁體中文', false),
  ('en', 'English', false),
  ('ja', '日本語', false),
];

class RootShell extends StatefulWidget {
  final ValueChanged<Locale> onLocaleChanged;
  const RootShell({super.key, required this.onLocaleChanged});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> with WidgetsBindingObserver {
  int _tab = 0;
  
  final AlertRepository _repository = firebaseReady
      ? FirestoreAlertRepository()
      : firebasePlatform
      ? const UnavailableAlertRepository()
      : RestAlertRepository();
  
  final EarthquakeRepository _quakes = firebaseReady
      ? FirestoreEarthquakeRepository()
      : firebasePlatform
      ? const UnavailableEarthquakeRepository()
      : RestEarthquakeRepository();
  final PushPrefsStore _pushPrefs = LocalPushPrefsStore();
  
  late final QaService _qa = firebaseReady
      ? CallableQaService()
      : firebasePlatform
      ? const UnavailableQaService()
      : MockQaService((_) => AppLocalizations.of(context)!.qaMockAnswer);

  
  bool _wide = false;
  String? _lang;
  StreamSubscription<PushNotice>? _pushNotices;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushService.instance.openUid.addListener(_openFromPush);
    _pushNotices = PushService.instance.foreground.listen(_showPushNotice);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromPush());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    if (lang != _lang) {
      _lang = lang;
      unawaited(_syncPush(lang));
    }
  }

  @override
  void dispose() {
    PushService.instance.openUid.removeListener(_openFromPush);
    WidgetsBinding.instance.removeObserver(this);
    _pushNotices?.cancel();
    if (_portraitOnly) SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  Future<void> _syncPush(String lang) async {
    if (!PushService.instance.enabled) return;
    try {
      final prefs = await _pushPrefs.load();
      if (prefs.counties.isNotEmpty) {
        await PushService.instance.requestPermission();
      }
      await PushService.instance.sync(prefs, lang);
    } catch (e) {
      debugPrint('Push: sync on start failed: $e');
    }
  }

  void _openFromPush() {
    final uid = PushService.instance.openUid.value;
    if (uid == null || _wide || !mounted) return;
    PushService.instance.openUid.value = null;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => AlertByUidScreen(uid: uid)));
  }

  
  void _showPushNotice(PushNotice n) {
    if (!mounted) return;
    final t = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        content: Text(
          n.body.isEmpty ? n.title : '${n.title}\n${n.body}',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        action: SnackBarAction(
          label: t.pushView,
          onPressed: () => PushService.instance.openUid.value = n.uid,
        ),
      ),
    );
  }

  
  
  bool _portraitOnly = false;

  @override
  void didChangeMetrics() => unawaited(_syncOrientation());

  Future<void> _syncOrientation() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    final display =
        WidgetsBinding.instance.platformDispatcher.implicitView?.display;
    if (display == null) return;
    final phone = display.size.shortestSide / display.devicePixelRatio < 600;
    final lock = phone && _tab == 2;
    if (lock == _portraitOnly) return;
    _portraitOnly = lock;
    try {
      await SystemChrome.setPreferredOrientations(
        lock ? const [DeviceOrientation.portraitUp] : const [],
      );
    } catch (e) {
      
      debugPrint('Orientation: $e');
      if (_portraitOnly == lock) _portraitOnly = !lock;
    }
  }

  
  static const _tabSections = [
    SiteSection.alerts,
    SiteSection.quakes,
    SiteSection.ask,
    SiteSection.help,
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      
      _wide = c.maxWidth >= siteWide && c.maxHeight >= 480;
      if (_wide) {
        return WideAppShell(
          alerts: _repository,
          quakes: _quakes,
          qa: _qa,
          pushPrefs: _pushPrefs,
          onLocaleChanged: widget.onLocaleChanged,
          initialSection: _tabSections[_tab],
          onSectionChanged: (s) {
            final i = _tabSections.indexOf(s);
            _tab = i < 0 ? 0 : i;
            unawaited(_syncOrientation());
          },
        );
      }
      return _phone(context);
    },
  );

  Widget _phone(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    final titles = [t.appTitle, t.tabQuake, t.qaTitle, t.helpTitle];
    
    const tabIcons = [
      Symbols.notifications_active_rounded,
      Symbols.earthquake_rounded,
      Symbols.support_agent_rounded,
      Symbols.call_rounded,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(tabIcons[_tab]),
            const SizedBox(width: 8),
            Flexible(
              child: _tab == 3
                  ? MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          titles[_tab],
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  : _tab == 0 && lang == 'en'
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(titles[_tab], maxLines: 1),
                    )
                  : Text(titles[_tab], overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: t.settingsTitle,
            iconSize: 28,
            icon: const Icon(Symbols.settings_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsScreen(pushPrefs: _pushPrefs),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: t.languageTitle,
            icon: const Icon(Symbols.language_rounded),
            iconSize: 28,
            onSelected: (code) =>
                widget.onLocaleChanged(code == 'zh' ? zhTW : Locale(code)),
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
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(repository: _repository),
          QuakeScreen(repository: _quakes),
          QaScreen(service: _qa),
          const HelpScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          if (_tab == 2 && i != 2) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
          setState(() => _tab = i);
          unawaited(_syncOrientation());
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Symbols.notifications_active_rounded),
            selectedIcon: const Icon(
              Symbols.notifications_active_rounded,
              fill: 1,
            ),
            label: t.tabAlerts,
          ),
          NavigationDestination(
            icon: const Icon(Symbols.earthquake_rounded),
            selectedIcon: const Icon(Symbols.earthquake_rounded, fill: 1),
            label: t.tabQuake,
          ),
          NavigationDestination(
            icon: const Icon(Symbols.support_agent_rounded),
            selectedIcon: const Icon(Symbols.support_agent_rounded, fill: 1),
            label: t.tabQa,
          ),
          NavigationDestination(
            icon: const Icon(Symbols.call_rounded),
            selectedIcon: const Icon(Symbols.call_rounded, fill: 1),
            label: t.tabHelp,
          ),
        ],
      ),
    );
  }
}
