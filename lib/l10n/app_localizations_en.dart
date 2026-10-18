// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint


class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Taiwan Disaster Alerts';

  @override
  String get tabAlerts => 'Alerts';

  @override
  String get tabQa => 'Q&A';

  @override
  String get tabHelp => 'Help';

  @override
  String get activeAlerts => 'Active Alerts';

  @override
  String activeCount(int count) {
    return '$count active';
  }

  @override
  String get filterAll => 'All';

  @override
  String get filterAllTypes => 'All';

  @override
  String get loadFailed =>
      'Could not load alerts. Check your connection and try again.';

  @override
  String get retry => 'Retry';

  @override
  String get noAlerts => 'No active alerts right now';

  @override
  String lastSynced(String time) {
    return 'Synced: $time';
  }

  @override
  String syncOverdue(String time) {
    return 'Synced: $time (no update for over 25 minutes; data may be out of date)';
  }

  @override
  String minutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String hoursAgo(int n) {
    return '$n h ago';
  }

  @override
  String daysAgo(int n) {
    return '$n d ago';
  }

  @override
  String get justNow => 'Just now';

  @override
  String get alertDetail => 'Alert Details';

  @override
  String get webSelectAlert => 'Select an alert on the left to see details.';

  @override
  String get sender => 'Issued by';

  @override
  String get updatedAt => 'Updated';

  @override
  String get expiresAt => 'Valid until';

  @override
  String get noExpiry => 'Not specified';

  @override
  String get category => 'Category';

  @override
  String get severityExtreme => 'Extreme';

  @override
  String get severityCritical => 'Critical';

  @override
  String get severityWarning => 'Warning';

  @override
  String get severityInfo => 'Info';

  @override
  String get sourceLanguageNote =>
      'Alert text is shown as issued by the agency (in Chinese).';

  @override
  String get needHelp => 'Need assistance?';

  @override
  String get callEmergency => 'Call 119';

  @override
  String get groupWeather => 'Weather';

  @override
  String get groupQuake => 'Earthquake & Tsunami';

  @override
  String get groupWater => 'Water Resources';

  @override
  String get groupFire => 'Fire & Accidents';

  @override
  String get groupTraffic => 'Traffic';

  @override
  String get groupLiving => 'Utilities & Daily Life';

  @override
  String get groupOther => 'Other';

  @override
  String get qaTitle => 'Disaster Q&A';

  @override
  String get qaHint =>
      'Ask a question, e.g. What should I do near an elevator during an earthquake?';

  @override
  String get qaSend => 'Send';

  @override
  String get qaWelcome =>
      'Hi, I can answer disaster-preparedness questions and cite my sources.';

  @override
  String get qaSources => 'Sources';

  @override
  String get qaPreviewNotice =>
      'The Q&A service is under construction. Replies below are samples.';

  @override
  String get qaMockAnswer =>
      '(Sample reply) Once the service is live, answers based on official disaster-preparedness sources will appear here.';

  @override
  String get helpTitle => 'Emergency Help';

  @override
  String get emergencySection => 'Emergency numbers';

  @override
  String get supportSection => 'Emotional support lines';

  @override
  String get prepOpenFromQa => 'See how to prepare';

  @override
  String get prepEntryDesc => 'Go-bag checklist and what to do in a disaster';

  @override
  String get prepTitle => 'Be prepared';

  @override
  String get fire119 => 'Fire & ambulance';

  @override
  String get police110 => 'Police';

  @override
  String get line1925 => 'Mental health support line (24 h, Mandarin)';

  @override
  String get line1990 => 'Foreigners In Taiwan Hotline (24 h, English)';

  @override
  String get closeLabel => 'Close';

  @override
  String copiedNumber(String number) {
    return 'Copied $number';
  }

  @override
  String copyNumber(String number) {
    return 'Copy $number';
  }

  @override
  String get callKoryu =>
      'Call the Japan-Taiwan Exchange Association, Taipei Office';

  @override
  String get koryuDomestic => 'Within Taiwan: 02-2713-8000';

  @override
  String get koryuHours =>
      'Weekdays 9:00–12:30, 13:30–17:30. Outside these hours and on holidays, the same number\'s voice guide connects to emergency contact (24 h).';

  @override
  String get lineKoryu => 'Japan-Taiwan Exchange Association, Taipei Office';

  @override
  String get koryuShort => 'Japan-Taiwan Exchange Assoc.';

  @override
  String get localHelpSection => 'Help in your language';

  @override
  String get emergencyShort => '119';

  @override
  String dialSemantics(String label) {
    return '$label';
  }

  @override
  String get line1995 => 'Lifeline (Mandarin)';

  @override
  String get line1980 => 'Teacher Chang hotline (Mandarin)';

  @override
  String get tapToCall => 'Tap to call';

  @override
  String get aiSummaryLabel => 'AI-translated summary';

  @override
  String get originalText => 'Original text from the issuing agency';

  @override
  String get showOriginalText => 'View the issuing agency\'s original text';

  @override
  String get aiSummaryDisclaimer =>
      'Summarized by AI. The issuing agency\'s notice prevails.';

  @override
  String get languageBeta => 'Beta';

  @override
  String get languageTitle => 'Language';

  @override
  String get tabQuake => 'Quakes';

  @override
  String get recentQuakes => 'Recent';

  @override
  String get historyMap => 'History map';

  @override
  String get magnitude => 'Magnitude';

  @override
  String get depth => 'Depth';

  @override
  String depthKm(String km) {
    return '$km km';
  }

  @override
  String get maxIntensity => 'Max intensity';

  @override
  String maxIntensityIn(String level, String counties) {
    return 'Max intensity $level ($counties)';
  }

  @override
  String get originTime => 'Time';

  @override
  String get epicenter => 'Epicenter';

  @override
  String get reportLink => 'CWA earthquake report';

  @override
  String get quakeSourceLine => 'Source: Central Weather Administration';

  @override
  String get sampleDataNotice =>
      'The earthquake data service is under construction. Showing sample data.';

  @override
  String historyCaption(int n) {
    return 'Earthquakes of magnitude 4.5+ around Taiwan, 1996–2026: $n events. Source: USGS';
  }

  @override
  String get quakeDetail => 'Earthquake Details';

  @override
  String get shallow => 'Depth < 30 km';

  @override
  String get intermediate => 'Depth 30–70 km';

  @override
  String get deep => 'Depth > 70 km';

  @override
  String get historyDepthKm => 'Depth (km)';

  @override
  String get qaRateLimited =>
      'You\'ve reached the question limit. Please try again later. In an emergency, call 119.';

  @override
  String get qaFailed =>
      'Unable to answer right now. Please try again later. In an emergency, call 119.';

  @override
  String get atLeast => 'or higher';

  @override
  String shownCount(int n) {
    return '$n shown';
  }

  @override
  String get pushTitle => 'Notification Settings';

  @override
  String get pushPreviewNotice =>
      'Notifications on iPhone and iPad aren\'t available yet. Your choices are saved on this device.';

  @override
  String get pushServiceUnavailable =>
      'The notification service is temporarily unavailable, so you won\'t receive notifications right now. Your choices are saved on this device. Please reopen the app later.';

  @override
  String majorAlertsBanner(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Critical or Extreme alerts in effect — view',
      one: '1 Critical or Extreme alert in effect — view',
    );
    return '$_temp0';
  }

  @override
  String get pushLevels => 'Alert levels';

  @override
  String get pushExtremeAlwaysOn =>
      'Extreme (red-level) alerts for your selected areas are always sent and cannot be turned off, like national emergency alerts.';

  @override
  String get pushCriticalDesc =>
      'Alerts whose official level is Critical. Alerts rated Critical by AI are not sent.';

  @override
  String get pushCriticalOffWarning =>
      'If turned off, you will not be notified of critical alerts for your selected areas.';

  @override
  String get pushCounties => 'Areas';

  @override
  String pushCountiesHint(int n) {
    return '$n selected. You can choose more than one.';
  }

  @override
  String get pushSelectAll => 'Select all';

  @override
  String get pushClearAll => 'Clear all';

  @override
  String get pushView => 'View';

  @override
  String get pushAlertEnded => 'This alert has ended.';

  @override
  String get pushWebUnavailable =>
      'Push notifications aren\'t available on the web version yet. Install the app to get notifications for Extreme and Critical alerts.';

  @override
  String get pushPermissionOff =>
      'Notifications are turned off for this app on this device, so you won\'t receive alerts. Turn them on in system settings.';

  @override
  String get pushScopeNote =>
      'What\'s sent: only Extreme alerts and alerts whose official level is Critical. Warning and Info alerts and earthquake reports are not sent for now.';

  @override
  String get pushCooldownNote =>
      'For the same area and alert type, you\'ll get at most one notification every 30 minutes. Extreme alerts are always sent.';

  @override
  String get affectedCounties => 'Affected areas';

  @override
  String countyWithLevel(String county, String level) {
    return '$county ($level)';
  }

  @override
  String get call1925 => 'Call 1925 mental health line (Mandarin)';

  @override
  String get crisisCall119 => 'Call 119 (fire & ambulance)';

  @override
  String get row119 => '119 Fire & ambulance';

  @override
  String get row1925 => '1925 Mental health line (Mandarin)';

  @override
  String get row1990 => '1990 English help line';

  @override
  String get call1990 => 'Call 1990 (English help)';

  @override
  String get hoursVary => 'Hours vary by area';

  @override
  String callFailed(String number) {
    return 'Couldn\'t start the call. Please dial $number directly.';
  }

  @override
  String get copy => 'Copy';

  @override
  String get openLinkFailed => 'Couldn\'t open this link.';

  @override
  String get qaTooLong =>
      'Questions can be up to 300 characters. Please shorten it and try again.';

  @override
  String get staleData => 'Showing offline data. It may be out of date.';

  @override
  String get noFreshData =>
      'Couldn\'t get the latest data. Check your connection and try again.';

  @override
  String get alertNoLongerActive =>
      'This alert has ended or been updated. Go back to the list for the latest information.';

  @override
  String get saveFailed => 'Couldn\'t save your settings. Please try again.';

  @override
  String get updateFailed => 'Update failed. Showing previously loaded data.';

  @override
  String get originalTitle => 'Original title';

  @override
  String get historyLoadFailed => 'Couldn\'t load historical earthquake data.';

  @override
  String callManual(String number) {
    return 'If no dialer opened, please dial $number directly.';
  }

  @override
  String get settingsLoadFailed => 'Couldn\'t load notification settings.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get recaptchaNotice => 'This site is protected by reCAPTCHA.';

  @override
  String get licensesTitle => 'Open-source licenses';

  @override
  String get dataSourcesTitle => 'Data sources';

  @override
  String get srcAlertsTitle => 'Alerts';

  @override
  String get srcAlertsBody =>
      'Public alert data (CAP format) compiled by the National Science and Technology Center for Disaster Reduction (NCDR) from the issuing agencies. Each alert\'s detail page links to the original alert; the official release prevails.';

  @override
  String get srcQuakesTitle => 'Earthquakes';

  @override
  String srcQuakesBody(String significant, String local) {
    return 'Central Weather Administration, MOTC: $significant (E-A0015-001) and $local (E-A0016-001), provided under the Open Government Data License, version 1.0.';
  }

  @override
  String get srcBoundaryTitle => 'County boundaries (alert detail map)';

  @override
  String get srcBoundaryBody =>
      'National Land Surveying and Mapping Center, Ministry of the Interior, \"Direct-controlled municipality, county and city boundaries (TWD97)\", version 1140318 (2025), provided under the Open Government Data License, version 1.0. Simplified in this app to show affected areas only.';

  @override
  String get srcHistoryTitle => 'Historical earthquake map';

  @override
  String get srcHistoryBody =>
      'U.S. Geological Survey (USGS) earthquake catalog: magnitude 4.5+ earthquakes around Taiwan, 1996–2026.';

  @override
  String get srcBasemapTitle => 'Earthquake location base map';

  @override
  String get srcBasemapBody =>
      'Maps are provided by Google. When a map is shown, your device connects directly to Google to load it, and Google handles that connection data under its Privacy Policy.';

  @override
  String get openSourcePage => 'Open source page';

  @override
  String openSourcePageFor(String title) {
    return 'Open source page: $title';
  }

  @override
  String get privacyQa =>
      'Questions you ask are sent to Google\'s Gemini to generate answers.';

  @override
  String get privacyNoStore =>
      'Our servers do not store the content of your questions. They only log the question type.';

  @override
  String get privacyIpHash =>
      'To limit usage, our servers keep only a one-way transformed code of your source IP, which cannot be directly reversed. It expires after about 2 hours.';

  @override
  String get privacyNoLogin =>
      'The app requires no sign-in and does not collect your name, phone number, or location.';

  @override
  String get privacyPushLocal =>
      'Notification settings are stored on this device. To send notifications, the areas, alert levels, and interface language you choose are registered as \"topics\" with Google\'s Firebase Cloud Messaging (FCM), and on iOS, notifications are then relayed by the Apple Push Notification service. What is registered does not include your name or phone number, and the app does not access your location. The web version does not support push notifications.';

  @override
  String get privacyMapTiles =>
      'Maps are provided by Google Maps. Your device connects directly to Google when loading maps.';

  @override
  String get privacyDataSource =>
      'Disaster data comes from the National Science and Technology Center for Disaster Reduction (NCDR) and the Central Weather Administration (CWA). Official announcements take precedence.';

  @override
  String get dataSource => 'Source';

  @override
  String dataSourceDetail(String sender) {
    return 'Issued by $sender, received via the National Science and Technology Center for Disaster Reduction (NCDR) alert platform. Official announcements take precedence.';
  }

  @override
  String dataSourceDetailShort(String sender) {
    return 'Issued by $sender, received via the National Science and Technology Center for Disaster Reduction (NCDR) alert platform.';
  }

  @override
  String get expired => 'Expired';

  @override
  String get alertExpired => 'This alert has passed its validity period.';

  @override
  String get qaCloudNotice =>
      'All your questions are uploaded to the cloud and answered by Google Gemini. Tap to read the privacy notice.';

  @override
  String get qaCloudNoticeShort => 'Questions go to the cloud · Privacy';

  @override
  String get qaRotatePortrait => 'Turn your phone upright to use Q&A.';

  @override
  String get levelUnrated => 'No official level';

  @override
  String get recentlyEnded => 'Ended in the past 24 hours';

  @override
  String get ended => 'Ended';

  @override
  String endedAtShort(String time) {
    return 'Ended $time';
  }

  @override
  String alertEnded(String time) {
    return 'This alert ended at $time.';
  }

  @override
  String get noRecentlyEnded => 'No alerts ended in the past 24 hours.';

  @override
  String get updating => 'Updating';

  @override
  String cwaAttribution(String year, String dataset, String datasetId) {
    return 'Provided by the Central Weather Administration, MOTC: $dataset ($datasetId), $year. Released under the Open Government Data License, version 1.0.';
  }

  @override
  String cwaAttributionNoYear(String dataset, String datasetId) {
    return 'Provided by the Central Weather Administration, MOTC: $dataset ($datasetId). Released under the Open Government Data License, version 1.0.';
  }

  @override
  String get datasetSignificant => 'Significant Earthquake Reports';

  @override
  String get datasetLocal => 'Local Felt Earthquake Reports';

  @override
  String get datasetQuakes => 'Significant and Local Felt Earthquake Reports';

  @override
  String get quakeReportDelay =>
      'Earthquake reports are published a few minutes after a quake, once intensity is manually confirmed. If you just felt shaking, it may not appear here yet.';

  @override
  String get localQuake => 'Local';

  @override
  String get byCounty => 'Alerts by area';

  @override
  String countyCount(String county, int n) {
    return '$county $n';
  }

  @override
  String get qaSearching => 'Looking it up…';

  @override
  String withLabel(String text, String label) {
    return '$text ($label)';
  }

  @override
  String groupedTitle(String title, int n) {
    return '$title: $n items';
  }

  @override
  String get groupedHint =>
      'This notice contains several items. Tap to see each one.';

  @override
  String syncFailedSince(String time) {
    return 'Last update failed. Last successful update: $time';
  }

  @override
  String get syncFailedNever => 'Last update failed. No successful update yet.';

  @override
  String get openDataLicense => 'Open Government Data License';

  @override
  String get noFilteredAlerts => 'No alerts match the current filters.';

  @override
  String get noLongerMatchesFilter =>
      'This alert no longer matches the current filters.';

  @override
  String get qaCrisisLinesShown =>
      'Helpline call buttons are now above the message box.';

  @override
  String get qaReport => 'Report this answer';

  @override
  String get qaReportReason => 'Reason';

  @override
  String get qaReportReasonIncorrect => 'Incorrect';

  @override
  String get qaReportReasonOutdated =>
      'Outdated or differs from official information';

  @override
  String get qaReportReasonOffensive => 'Inappropriate or offensive';

  @override
  String get qaReportReasonOther => 'Other';

  @override
  String get qaReportNote => 'Details (optional)';

  @override
  String get qaReportNotice =>
      'Your report sends this question and answer to the developer. It is kept for 90 days and used to improve answers. Please do not include personal information such as your name or phone number in the details.';

  @override
  String get qaReportSend => 'Send';

  @override
  String get qaReportThanks => 'Report received. Thank you.';

  @override
  String get qaReportFailed =>
      'The report was not sent. Please try again later.';

  @override
  String get qaReportRateLimited => 'Too many reports. Please try again later.';

  @override
  String get qaReportDailyFull =>
      'Today\'s report limit has been reached. Please email us using the contact address in the privacy notice.';

  @override
  String qaReportDailyFullEmail(String email) {
    return 'Today\'s report limit has been reached. Please email us at $email.';
  }

  @override
  String get aboutBody1 =>
      'Taiwan Disaster Alerts brings the active disaster alerts issued by government agencies together in one place, along with earthquake information, a disaster Q&A and preparedness guides.';

  @override
  String get aboutBody2 =>
      'This service is developed by an individual. It is not a government service and is not affiliated with the data source agencies.';

  @override
  String get aboutContact => 'Contact us';

  @override
  String get aboutBuiltWithTitle => 'Built with';

  @override
  String get aboutBuiltWithBody =>
      'This app is built with Google Cloud, Firebase, Google Maps, Gemini, Flutter and Google Antigravity.';

  @override
  String get aboutTrademarks =>
      'These names and Google are trademarks of Google LLC.';

  @override
  String get aboutUsTitle => 'About us';

  @override
  String get aboutBody3 =>
      'If anything here differs from the issuing agency\'s notice, the notice prevails. In an emergency, call 119 or 110 directly.';

  @override
  String get backToGroup => 'Back to group';
}
