// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint


class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '防災速報';

  @override
  String get tabAlerts => '示警';

  @override
  String get tabQa => '災害問答';

  @override
  String get tabHelp => '緊急協助';

  @override
  String get activeAlerts => '目前生效中的示警';

  @override
  String activeCount(int count) {
    return '共 $count 則';
  }

  @override
  String get filterAll => '全部';

  @override
  String get filterAllTypes => '全部';

  @override
  String get loadFailed => '讀取示警失敗，請檢查網路後重試';

  @override
  String get retry => '重試';

  @override
  String get noAlerts => '目前沒有生效中的示警';

  @override
  String lastSynced(String time) {
    return '資料同步：$time';
  }

  @override
  String syncOverdue(String time) {
    return '資料同步：$time（超過 25 分鐘沒有更新，資料可能不是最新）';
  }

  @override
  String minutesAgo(int n) {
    return '$n 分鐘前';
  }

  @override
  String hoursAgo(int n) {
    return '$n 小時前';
  }

  @override
  String daysAgo(int n) {
    return '$n 天前';
  }

  @override
  String get justNow => '剛剛';

  @override
  String get alertDetail => '示警詳情';

  @override
  String get webSelectAlert => '從左邊選一則示警查看詳情。';

  @override
  String get sender => '發布單位';

  @override
  String get updatedAt => '更新時間';

  @override
  String get expiresAt => '有效至';

  @override
  String get noExpiry => '未註明';

  @override
  String get category => '分類';

  @override
  String get severityExtreme => '極重大';

  @override
  String get severityCritical => '重大';

  @override
  String get severityWarning => '警戒';

  @override
  String get severityInfo => '資訊';

  @override
  String get sourceLanguageNote => '示警內容為發布單位原文。';

  @override
  String get needHelp => '需要幫助？';

  @override
  String get callEmergency => '撥打 119';

  @override
  String get groupWeather => '氣象';

  @override
  String get groupQuake => '地震海嘯';

  @override
  String get groupWater => '水利';

  @override
  String get groupFire => '火災事故';

  @override
  String get groupTraffic => '交通';

  @override
  String get groupLiving => '民生';

  @override
  String get groupOther => '其他';

  @override
  String get qaTitle => '災害問答';

  @override
  String get qaHint => '輸入防災問題，例如：地震時人在電梯旁怎麼辦？';

  @override
  String get qaSend => '送出';

  @override
  String get qaWelcome => '你好，我可以回答防災相關問題，並附上資料來源。';

  @override
  String get qaSources => '資料來源';

  @override
  String get qaPreviewNotice => '問答服務建置中，目前顯示的是範例回應。';

  @override
  String get qaMockAnswer => '（範例回應）問答服務上線後，這裡會顯示依官方防災資料產生的回答。';

  @override
  String get helpTitle => '緊急協助';

  @override
  String get emergencySection => '緊急電話';

  @override
  String get supportSection => '心理支持專線';

  @override
  String get prepOpenFromQa => '查看防災準備';

  @override
  String get prepEntryDesc => '避難包清單、災害應變';

  @override
  String get prepTitle => '防災準備';

  @override
  String get fire119 => '消防、救護';

  @override
  String get police110 => '報案';

  @override
  String get line1925 => '安心專線（24 小時）';

  @override
  String get line1990 => '外來人士在臺生活諮詢服務熱線（24 小時）';

  @override
  String get closeLabel => '關閉';

  @override
  String copiedNumber(String number) {
    return '已複製 $number';
  }

  @override
  String copyNumber(String number) {
    return '複製 $number';
  }

  @override
  String get callKoryu => '撥打日本台灣交流協會台北事務所';

  @override
  String get koryuDomestic => '臺灣國內撥 02-2713-8000';

  @override
  String get koryuHours =>
      '平日 9:00–12:30、13:30–17:30；其他時間與假日撥同一支號碼，依語音引導轉緊急聯絡（24 小時）';

  @override
  String get lineKoryu => '日本台灣交流協會台北事務所';

  @override
  String get koryuShort => '交流協會';

  @override
  String get localHelpSection => '外語協助';

  @override
  String get emergencyShort => '119';

  @override
  String dialSemantics(String label) {
    return '$label';
  }

  @override
  String get line1995 => '生命線';

  @override
  String get line1980 => '張老師';

  @override
  String get tapToCall => '點一下撥號';

  @override
  String get aiSummaryLabel => 'AI 速報摘要';

  @override
  String get originalText => '發布單位原文';

  @override
  String get showOriginalText => '查看發布單位原文';

  @override
  String get aiSummaryDisclaimer => 'AI 整理，內容以發布單位公告為準。';

  @override
  String get languageBeta => 'Beta';

  @override
  String get languageTitle => '介面語言';

  @override
  String get tabQuake => '地震';

  @override
  String get recentQuakes => '近期地震';

  @override
  String get historyMap => '歷史地震地圖';

  @override
  String get magnitude => '規模';

  @override
  String get depth => '深度';

  @override
  String depthKm(String km) {
    return '$km 公里';
  }

  @override
  String get maxIntensity => '最大震度';

  @override
  String maxIntensityIn(String level, String counties) {
    return '最大震度 $level（$counties）';
  }

  @override
  String get originTime => '發生時間';

  @override
  String get epicenter => '震央';

  @override
  String get reportLink => '中央氣象署地震報告';

  @override
  String get quakeSourceLine => '資料來源：中央氣象署';

  @override
  String get sampleDataNotice => '地震資料服務建置中，目前顯示的是範例資料。';

  @override
  String historyCaption(int n) {
    return '1996–2026 年臺灣周邊規模 4.5 以上的地震，共 $n 筆。資料來源：USGS';
  }

  @override
  String get quakeDetail => '地震詳情';

  @override
  String get shallow => '深度 < 30 公里';

  @override
  String get intermediate => '深度 30–70 公里';

  @override
  String get deep => '深度 > 70 公里';

  @override
  String get historyDepthKm => '深度（公里）';

  @override
  String get qaRateLimited => '提問次數已達上限，請稍後再試。如有緊急狀況請撥 119。';

  @override
  String get qaFailed => '暫時無法回答，請稍後再試。如有緊急狀況請撥 119。';

  @override
  String get atLeast => '以上';

  @override
  String shownCount(int n) {
    return '顯示 $n 筆';
  }

  @override
  String get pushTitle => '推播設定';

  @override
  String get pushPreviewNotice => 'iPhone／iPad 版目前還不支援推播，設定會先存在這個裝置上。';

  @override
  String get pushServiceUnavailable =>
      '推播服務暫時無法使用，現在收不到通知；設定會先存在這個裝置上。請稍後重新開啟 App。';

  @override
  String majorAlertsBanner(int n) {
    return '目前有 $n 則重大以上示警，點此查看';
  }

  @override
  String get pushLevels => '通知等級';

  @override
  String get pushExtremeAlwaysOn => '所選縣市的極重大（紅色等級）示警一律通知，無法關閉，比照國家級警報。';

  @override
  String get pushCriticalDesc => '官方等級為重大的示警。AI 判定為重大的不會通知。';

  @override
  String get pushCriticalOffWarning => '關閉後，你所選縣市的重大示警也不會通知。';

  @override
  String get pushCounties => '通知縣市';

  @override
  String pushCountiesHint(int n) {
    return '已選 $n 個，可複選。';
  }

  @override
  String get pushSelectAll => '全選';

  @override
  String get pushClearAll => '全部取消';

  @override
  String get pushView => '查看';

  @override
  String get pushAlertEnded => '這則示警已結束。';

  @override
  String get pushWebUnavailable => '網頁版目前不提供推播，請安裝 App 接收重大示警通知。';

  @override
  String get pushPermissionOff => '這台裝置沒有允許本 App 顯示通知，所以收不到推播。請到系統設定開啟通知。';

  @override
  String get pushScopeNote => '通知範圍：只通知極重大與官方等級為重大的示警；警戒、資訊與地震報告目前不通知。';

  @override
  String get pushCooldownNote => '同一縣市、同一類示警 30 分鐘內最多通知一次；極重大示警每次都通知。';

  @override
  String get affectedCounties => '影響縣市';

  @override
  String countyWithLevel(String county, String level) {
    return '$county（$level）';
  }

  @override
  String get call1925 => '撥打 1925 安心專線';

  @override
  String get crisisCall119 => '撥打 119 消防救護';

  @override
  String get row119 => '119 消防救護';

  @override
  String get row1925 => '1925 安心專線';

  @override
  String get row1990 => '撥打 1990';

  @override
  String get call1990 => '撥打 1990';

  @override
  String get hoursVary => '服務時段依各地不同';

  @override
  String callFailed(String number) {
    return '無法自動撥號，請直接撥打 $number。';
  }

  @override
  String get copy => '複製';

  @override
  String get openLinkFailed => '無法開啟這個連結。';

  @override
  String get qaTooLong => '問題最多 300 字，請縮短後再送出。';

  @override
  String get staleData => '目前顯示的是離線資料，可能不是最新狀態。';

  @override
  String get noFreshData => '尚未取得最新資料，請確認網路後重試。';

  @override
  String get alertNoLongerActive => '這則示警已解除或內容已更新，請回到列表查看最新狀態。';

  @override
  String get saveFailed => '設定儲存失敗，請再試一次。';

  @override
  String get updateFailed => '更新失敗，目前顯示的是先前的資料。';

  @override
  String get originalTitle => '原文標題';

  @override
  String get historyLoadFailed => '無法讀取歷史地震資料。';

  @override
  String callManual(String number) {
    return '如果沒有開啟撥號程式，請直接撥打 $number。';
  }

  @override
  String get settingsLoadFailed => '無法讀取推播設定。';

  @override
  String get settingsTitle => '設定';

  @override
  String get privacyTitle => '隱私說明';

  @override
  String get recaptchaNotice => '本網站受 reCAPTCHA 保護。';

  @override
  String get licensesTitle => '開源授權';

  @override
  String get dataSourcesTitle => '資料來源';

  @override
  String get srcAlertsTitle => '示警';

  @override
  String get srcAlertsBody =>
      '國家災害防救科技中心彙整各機關發布的示警公開資料（CAP 格式）。每則示警的詳情頁附原始示警連結，內容以官方發布為準。';

  @override
  String get srcQuakesTitle => '地震';

  @override
  String srcQuakesBody(String significant, String local) {
    return '交通部中央氣象署「$significant」（E-A0015-001）與「$local」（E-A0016-001），依政府資料開放授權條款－第 1 版提供。';
  }

  @override
  String get srcBoundaryTitle => '縣市界線（示警詳情頁地圖）';

  @override
  String get srcBoundaryBody =>
      '內政部國土測繪中心 2025 年「直轄市、縣市界線(TWD97經緯度)」（版本 1140318），依政府資料開放授權條款－第 1 版提供。App 內經過簡化，只用於示意受影響縣市。';

  @override
  String get srcHistoryTitle => '歷史地震地圖';

  @override
  String get srcHistoryBody => '美國地質調查所（USGS）地震目錄：1996–2026 年臺灣周邊規模 4.5 以上的地震。';

  @override
  String get srcBasemapTitle => '地震位置底圖';

  @override
  String get srcBasemapBody =>
      '地圖由 Google 提供。顯示地圖時，裝置會直接連到 Google 載入地圖，這些連線資料由 Google 依其隱私權政策處理。';

  @override
  String get openSourcePage => '開啟來源網頁';

  @override
  String openSourcePageFor(String title) {
    return '開啟來源網頁：$title';
  }

  @override
  String get privacyQa => '問答的問題會送到 Google 的 Gemini 產生回答。';

  @override
  String get privacyNoStore => '後端不儲存問題內容，只記錄問題類型。';

  @override
  String get privacyIpHash => '為了限制使用次數，後端只記錄來源 IP 經單向轉換後的代碼，無法直接還原，約 2 小時後失效。';

  @override
  String get privacyNoLogin => 'App 不需要登入，不蒐集姓名、電話或位置。';

  @override
  String get privacyPushLocal =>
      '推播設定存在這個裝置上。為了送出通知，你選的縣市、等級與介面語言會以「主題」的形式登記在 Google 的 Firebase 雲端通訊（FCM），iOS 的通知再由 Apple 推播服務轉送；登記的內容不含姓名、電話，也不會取得你的定位。網頁版沒有推播。';

  @override
  String get privacyMapTiles => '地圖由 Google 地圖提供，載入時裝置會直接連到 Google。';

  @override
  String get privacyDataSource => '防災資料來自國家災害防救科技中心與中央氣象署，內容以官方發布為準。';

  @override
  String get dataSource => '資料來源';

  @override
  String dataSourceDetail(String sender) {
    return '$sender發布，經國家災害防救科技中心（NCDR）示警平台取得。內容以官方發布為準。';
  }

  @override
  String dataSourceDetailShort(String sender) {
    return '$sender發布，經國家災害防救科技中心（NCDR）示警平台取得。';
  }

  @override
  String get expired => '已過期';

  @override
  String get alertExpired => '這則示警已超過有效期限。';

  @override
  String get qaCloudNotice => '你的所有問題都會上傳到雲端，由 Google Gemini 產生回答。點此看隱私說明。';

  @override
  String get qaCloudNoticeShort => '問題會上傳雲端 · 隱私說明';

  @override
  String get qaRotatePortrait => '請將手機轉為直向使用災害問答';

  @override
  String get levelUnrated => '未分級';

  @override
  String get recentlyEnded => '過去 24 小時已結束';

  @override
  String get ended => '已結束';

  @override
  String endedAtShort(String time) {
    return '$time 結束';
  }

  @override
  String alertEnded(String time) {
    return '這則示警已於 $time 結束。';
  }

  @override
  String get noRecentlyEnded => '過去 24 小時沒有已結束的示警。';

  @override
  String get updating => '更新中';

  @override
  String cwaAttribution(String year, String dataset, String datasetId) {
    return '提供機關／交通部中央氣象署 $year 年「$dataset」（$datasetId）。依政府資料開放授權條款－第 1 版釋出。';
  }

  @override
  String cwaAttributionNoYear(String dataset, String datasetId) {
    return '提供機關／交通部中央氣象署「$dataset」（$datasetId）。依政府資料開放授權條款－第 1 版釋出。';
  }

  @override
  String get datasetSignificant => '顯著有感地震報告';

  @override
  String get datasetLocal => '小區域有感地震報告';

  @override
  String get datasetQuakes => '顯著有感地震報告、小區域有感地震報告';

  @override
  String get quakeReportDelay =>
      '地震報告要由人工確認震度，通常在發生後幾分鐘才會發布。剛感覺到搖晃時，這裡可能還沒有資料。';

  @override
  String get localQuake => '小區域';

  @override
  String get byCounty => '各縣市示警';

  @override
  String countyCount(String county, int n) {
    return '$county $n 件';
  }

  @override
  String get qaSearching => '正在查詢…';

  @override
  String withLabel(String text, String label) {
    return '$text（$label）';
  }

  @override
  String groupedTitle(String title, int n) {
    return '$title：$n 則';
  }

  @override
  String get groupedHint => '同一則通報底下有多筆，點開查看每一則。';

  @override
  String syncFailedSince(String time) {
    return '最近一次更新失敗，最後成功：$time';
  }

  @override
  String get syncFailedNever => '最近一次更新失敗，尚未成功同步過。';

  @override
  String get openDataLicense => '政府資料開放授權條款';

  @override
  String get noFilteredAlerts => '沒有符合目前篩選的示警。';

  @override
  String get noLongerMatchesFilter => '這則示警已不符合目前的篩選條件。';

  @override
  String get qaCrisisLinesShown => '輸入框上方有求助專線按鈕，可以直接撥打。';

  @override
  String get qaReport => '回報這則回答';

  @override
  String get qaReportReason => '原因';

  @override
  String get qaReportReasonIncorrect => '不正確';

  @override
  String get qaReportReasonOutdated => '資訊過時或與官方不符';

  @override
  String get qaReportReasonOffensive => '不恰當或冒犯';

  @override
  String get qaReportReasonOther => '其他';

  @override
  String get qaReportNote => '補充說明（選填）';

  @override
  String get qaReportNotice =>
      '回報會把這則問題與回答傳給開發者，保存 90 天，用來改善回答。請不要在說明中填寫姓名、電話等個人資料。';

  @override
  String get qaReportSend => '送出';

  @override
  String get qaReportThanks => '已收到回報，謝謝。';

  @override
  String get qaReportFailed => '回報沒有送出，請稍後再試。';

  @override
  String get qaReportRateLimited => '回報太頻繁，請稍後再試。';

  @override
  String get qaReportDailyFull => '今天的回報已額滿，請改用隱私說明裡的聯絡信箱寄信給我們。';

  @override
  String qaReportDailyFullEmail(String email) {
    return '今天的回報已額滿，請改寄信到 $email。';
  }

  @override
  String get aboutBody1 => '防災速報把各機關發布、目前仍生效的災害示警整理在同一個畫面，並提供地震資訊、災害問答與防災準備內容。';

  @override
  String get aboutBody2 => '本服務由個人開發，不是政府機關的服務，與資料來源機關沒有隸屬關係。';

  @override
  String get aboutContact => '聯絡我們';

  @override
  String get aboutBuiltWithTitle => '使用技術';

  @override
  String get aboutBuiltWithBody =>
      '本 App 使用下列技術開發：Google Cloud、Firebase、Google Maps、Gemini、Flutter、Google Antigravity。';

  @override
  String get aboutTrademarks => '以上名稱與 Google 皆為 Google LLC 的商標。';

  @override
  String get aboutUsTitle => '關於我們';

  @override
  String get aboutBody3 => '示警內容以發布單位的公告為準；遇到緊急狀況請直接撥打 119 或 110。';

  @override
  String get backToGroup => '返回群組';
}
