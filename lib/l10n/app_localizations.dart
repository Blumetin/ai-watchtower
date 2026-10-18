import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint




























abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  
  
  
  
  
  
  
  
  
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  
  
  
  String get appTitle;

  
  
  
  String get tabAlerts;

  
  
  String get tabQa;

  
  
  
  String get tabHelp;

  
  
  
  
  String get activeAlerts;

  
  
  
  
  String activeCount(int count);

  
  
  
  String get filterAll;

  
  
  
  
  String get filterAllTypes;

  
  
  
  
  String get loadFailed;

  
  
  String get retry;

  
  
  
  String get noAlerts;

  
  
  
  
  String lastSynced(String time);

  
  
  
  
  String syncOverdue(String time);

  
  
  
  
  String minutesAgo(int n);

  
  
  
  
  String hoursAgo(int n);

  
  
  
  
  String daysAgo(int n);

  
  
  
  String get justNow;

  
  
  
  
  String get alertDetail;

  
  
  
  
  String get webSelectAlert;

  
  
  String get sender;

  
  
  
  String get updatedAt;

  
  
  
  String get expiresAt;

  
  
  
  String get noExpiry;

  
  
  
  String get category;

  
  
  
  
  String get severityExtreme;

  
  
  
  
  String get severityCritical;

  
  
  
  
  String get severityWarning;

  
  
  
  
  String get severityInfo;

  
  
  
  
  String get sourceLanguageNote;

  
  
  
  String get needHelp;

  
  
  
  
  String get callEmergency;

  
  
  
  
  String get groupWeather;

  
  
  
  
  String get groupQuake;

  
  
  
  
  String get groupWater;

  
  
  
  String get groupFire;

  
  
  
  
  String get groupTraffic;

  
  
  
  
  String get groupLiving;

  
  
  
  
  String get groupOther;

  
  
  
  String get qaTitle;

  
  
  String get qaHint;

  
  
  String get qaSend;

  
  
  
  String get qaWelcome;

  
  
  
  String get qaSources;

  
  
  
  
  String get qaPreviewNotice;

  
  
  
  
  String get qaMockAnswer;

  
  
  
  String get helpTitle;

  
  
  
  
  String get emergencySection;

  
  
  
  
  String get supportSection;

  
  
  
  
  String get prepOpenFromQa;

  
  
  
  
  String get prepEntryDesc;

  
  
  
  String get prepTitle;

  
  
  
  String get fire119;

  
  
  
  String get police110;

  
  
  
  String get line1925;

  
  
  
  String get line1990;

  
  
  
  
  String get closeLabel;

  
  
  
  
  String copiedNumber(String number);

  
  
  
  
  String copyNumber(String number);

  
  
  
  String get callKoryu;

  
  
  
  
  String get koryuDomestic;

  
  
  
  
  String get koryuHours;

  
  
  
  String get lineKoryu;

  
  
  
  
  String get koryuShort;

  
  
  
  
  String get localHelpSection;

  
  
  
  
  String get emergencyShort;

  
  
  
  
  String dialSemantics(String label);

  
  
  
  String get line1995;

  
  
  
  String get line1980;

  
  
  
  String get tapToCall;

  
  
  
  
  String get aiSummaryLabel;

  
  
  
  
  String get originalText;

  
  
  
  
  String get showOriginalText;

  
  
  
  
  String get aiSummaryDisclaimer;

  
  
  
  
  String get languageBeta;

  
  
  
  
  String get languageTitle;

  
  
  
  String get tabQuake;

  
  
  
  
  String get recentQuakes;

  
  
  
  
  String get historyMap;

  
  
  
  String get magnitude;

  
  
  String get depth;

  
  
  
  
  String depthKm(String km);

  
  
  
  
  String get maxIntensity;

  
  
  
  
  String maxIntensityIn(String level, String counties);

  
  
  
  
  String get originTime;

  
  
  
  String get epicenter;

  
  
  
  
  String get reportLink;

  
  
  
  
  String get quakeSourceLine;

  
  
  
  
  String get sampleDataNotice;

  
  
  
  
  String historyCaption(int n);

  
  
  
  
  String get quakeDetail;

  
  
  
  String get shallow;

  
  
  
  
  String get intermediate;

  
  
  String get deep;

  
  
  
  
  String get historyDepthKm;

  
  
  
  
  String get qaRateLimited;

  
  
  
  String get qaFailed;

  
  
  
  String get atLeast;

  
  
  
  
  String shownCount(int n);

  
  
  
  String get pushTitle;

  
  
  
  
  String get pushPreviewNotice;

  
  
  
  
  String get pushServiceUnavailable;

  
  
  
  
  String majorAlertsBanner(int n);

  
  
  
  
  String get pushLevels;

  
  
  
  
  String get pushExtremeAlwaysOn;

  
  
  
  
  String get pushCriticalDesc;

  
  
  
  
  String get pushCriticalOffWarning;

  
  
  
  
  String get pushCounties;

  
  
  
  
  String pushCountiesHint(int n);

  
  
  
  
  String get pushSelectAll;

  
  
  
  
  String get pushClearAll;

  
  
  
  String get pushView;

  
  
  
  
  String get pushAlertEnded;

  
  
  
  
  String get pushWebUnavailable;

  
  
  
  
  String get pushPermissionOff;

  
  
  
  
  String get pushScopeNote;

  
  
  
  
  String get pushCooldownNote;

  
  
  
  
  String get affectedCounties;

  
  
  
  
  String countyWithLevel(String county, String level);

  
  
  
  String get call1925;

  
  
  
  
  String get crisisCall119;

  
  
  String get row119;

  
  
  
  String get row1925;

  
  
  
  String get row1990;

  
  
  
  String get call1990;

  
  
  
  String get hoursVary;

  
  
  
  
  String callFailed(String number);

  
  
  String get copy;

  
  
  
  
  String get openLinkFailed;

  
  
  
  String get qaTooLong;

  
  
  
  String get staleData;

  
  
  
  
  String get noFreshData;

  
  
  
  
  String get alertNoLongerActive;

  
  
  
  
  String get saveFailed;

  
  
  
  
  String get updateFailed;

  
  
  
  
  String get originalTitle;

  
  
  
  
  String get historyLoadFailed;

  
  
  
  
  String callManual(String number);

  
  
  
  
  String get settingsLoadFailed;

  
  
  
  
  String get settingsTitle;

  
  
  
  
  String get privacyTitle;

  
  
  
  
  String get recaptchaNotice;

  
  
  
  
  String get licensesTitle;

  
  
  
  
  String get dataSourcesTitle;

  
  
  
  
  String get srcAlertsTitle;

  
  
  
  
  String get srcAlertsBody;

  
  
  
  
  String get srcQuakesTitle;

  
  
  
  
  String srcQuakesBody(String significant, String local);

  
  
  
  
  String get srcBoundaryTitle;

  
  
  
  
  String get srcBoundaryBody;

  
  
  
  
  String get srcHistoryTitle;

  
  
  
  
  String get srcHistoryBody;

  
  
  
  
  String get srcBasemapTitle;

  
  
  
  
  String get srcBasemapBody;

  
  
  
  
  String get openSourcePage;

  
  
  
  
  String openSourcePageFor(String title);

  
  
  
  String get privacyQa;

  
  
  
  
  String get privacyNoStore;

  
  
  
  
  String get privacyIpHash;

  
  
  
  
  String get privacyNoLogin;

  
  
  
  
  String get privacyPushLocal;

  
  
  
  
  String get privacyMapTiles;

  
  
  
  
  String get privacyDataSource;

  
  
  
  
  String get dataSource;

  
  
  
  
  String dataSourceDetail(String sender);

  
  
  
  
  String dataSourceDetailShort(String sender);

  
  
  
  String get expired;

  
  
  
  
  String get alertExpired;

  
  
  
  
  String get qaCloudNotice;

  
  
  
  
  String get qaCloudNoticeShort;

  
  
  
  
  String get qaRotatePortrait;

  
  
  
  
  String get levelUnrated;

  
  
  
  
  String get recentlyEnded;

  
  
  String get ended;

  
  
  
  
  String endedAtShort(String time);

  
  
  
  
  String alertEnded(String time);

  
  
  
  
  String get noRecentlyEnded;

  
  
  
  String get updating;

  
  
  
  
  String cwaAttribution(String year, String dataset, String datasetId);

  
  
  
  
  String cwaAttributionNoYear(String dataset, String datasetId);

  
  
  
  
  String get datasetSignificant;

  
  
  
  
  String get datasetLocal;

  
  
  
  
  String get datasetQuakes;

  
  
  
  
  String get quakeReportDelay;

  
  
  
  
  String get localQuake;

  
  
  
  String get byCounty;

  
  
  
  
  String countyCount(String county, int n);

  
  
  
  
  String get qaSearching;

  
  
  
  
  String withLabel(String text, String label);

  
  
  
  
  String groupedTitle(String title, int n);

  
  
  
  
  String get groupedHint;

  
  
  
  
  String syncFailedSince(String time);

  
  
  
  
  String get syncFailedNever;

  
  
  
  
  String get openDataLicense;

  
  
  
  
  String get noFilteredAlerts;

  
  
  
  
  String get noLongerMatchesFilter;

  
  
  
  
  String get qaCrisisLinesShown;

  
  
  
  String get qaReport;

  
  
  
  
  String get qaReportReason;

  
  
  
  
  String get qaReportReasonIncorrect;

  
  
  
  
  String get qaReportReasonOutdated;

  
  
  
  
  String get qaReportReasonOffensive;

  
  
  
  
  String get qaReportReasonOther;

  
  
  
  
  String get qaReportNote;

  
  
  
  
  String get qaReportNotice;

  
  
  
  
  String get qaReportSend;

  
  
  
  
  String get qaReportThanks;

  
  
  
  
  String get qaReportFailed;

  
  
  
  
  String get qaReportRateLimited;

  
  
  
  
  String get qaReportDailyFull;

  
  
  
  
  String qaReportDailyFullEmail(String email);

  
  
  
  
  String get aboutBody1;

  
  
  
  
  String get aboutBody2;

  
  
  
  
  String get aboutContact;

  
  
  
  
  String get aboutBuiltWithTitle;

  
  
  
  
  String get aboutBuiltWithBody;

  
  
  
  
  String get aboutTrademarks;

  
  
  
  
  String get aboutUsTitle;

  
  
  
  
  String get aboutBody3;

  
  
  
  
  String get backToGroup;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
