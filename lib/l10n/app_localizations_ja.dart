// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint


class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '防災速報';

  @override
  String get tabAlerts => '警報';

  @override
  String get tabQa => '防災Q&A';

  @override
  String get tabHelp => '緊急連絡';

  @override
  String get activeAlerts => '発表中の警報';

  @override
  String activeCount(int count) {
    return '$count 件の警報';
  }

  @override
  String get filterAll => 'すべて';

  @override
  String get filterAllTypes => 'すべての種類';

  @override
  String get loadFailed => '警報を読み込めませんでした。接続を確認して再試行してください。';

  @override
  String get retry => '再試行';

  @override
  String get noAlerts => '現在発表中の警報はありません';

  @override
  String lastSynced(String time) {
    return '最終更新：$time';
  }

  @override
  String syncOverdue(String time) {
    return '最終更新：$time（25分以上新しい情報が届いていません。最新でない可能性があります）';
  }

  @override
  String minutesAgo(int n) {
    return '$n分前';
  }

  @override
  String hoursAgo(int n) {
    return '$n時間前';
  }

  @override
  String daysAgo(int n) {
    return '$n日前';
  }

  @override
  String get justNow => 'たった今';

  @override
  String get alertDetail => '警報の詳細';

  @override
  String get webSelectAlert => '左の一覧から警報を選ぶと詳細が表示されます。';

  @override
  String get sender => '発表機関';

  @override
  String get updatedAt => '更新日時';

  @override
  String get expiresAt => '警報の有効期限';

  @override
  String get noExpiry => '記載なし';

  @override
  String get category => '分類';

  @override
  String get severityExtreme => '極めて重大';

  @override
  String get severityCritical => '重大';

  @override
  String get severityWarning => '警戒';

  @override
  String get severityInfo => '情報';

  @override
  String get sourceLanguageNote => '警報の本文は発表機関の原文（中国語・繁体字）です。';

  @override
  String get needHelp => '助けが必要ですか？';

  @override
  String get callEmergency => '119（救急・消防／中国語）';

  @override
  String get groupWeather => '気象';

  @override
  String get groupQuake => '地震・津波';

  @override
  String get groupWater => '水利';

  @override
  String get groupFire => '火災・事故';

  @override
  String get groupTraffic => '交通';

  @override
  String get groupLiving => '生活';

  @override
  String get groupOther => 'その他';

  @override
  String get qaTitle => '防災Q&A';

  @override
  String get qaHint => '防災の質問を入力（例：地震のとき、エレベーターの近くにいたらどうする？）';

  @override
  String get qaSend => '送信';

  @override
  String get qaWelcome => 'こんにちは。防災に関する質問にお答えします。公的資料に基づく回答には、回答の下に情報源が表示されます。';

  @override
  String get qaSources => '情報源';

  @override
  String get qaPreviewNotice => 'Q&Aサービスは準備中です。表示されるのは回答の例です。';

  @override
  String get qaMockAnswer => '（回答例）サービス開始後は、公式の防災資料にもとづく回答がここに表示されます。';

  @override
  String get helpTitle => '緊急連絡';

  @override
  String get emergencySection => '緊急電話';

  @override
  String get supportSection => '心の相談窓口';

  @override
  String get prepOpenFromQa => '災害への備えを見る';

  @override
  String get prepEntryDesc => '非常用持ち出し袋、災害時の行動';

  @override
  String get prepTitle => '災害への備え';

  @override
  String get fire119 => '消防・救急（中国語）';

  @override
  String get police110 => '警察（中国語）';

  @override
  String get line1925 => 'メンタルヘルス相談（24時間）・中国語';

  @override
  String get line1990 => '台湾在住の外国人向け生活相談ホットライン（24時間・日本語）';

  @override
  String get closeLabel => '閉じる';

  @override
  String copiedNumber(String number) {
    return '$numberをコピーしました';
  }

  @override
  String copyNumber(String number) {
    return '$numberをコピー';
  }

  @override
  String get callKoryu => '日本台湾交流協会台北事務所に電話';

  @override
  String get koryuDomestic => '台湾国内からは 02-2713-8000';

  @override
  String get koryuHours =>
      '平日 9:00〜12:30、13:30〜17:30。時間外・休日も同じ番号で、音声案内に従うと緊急連絡につながります（24 時間）';

  @override
  String get lineKoryu => '日本台湾交流協会台北事務所';

  @override
  String get koryuShort => '交流協会';

  @override
  String get localHelpSection => '日本語での相談';

  @override
  String get emergencyShort => '119';

  @override
  String dialSemantics(String label) {
    return '$labelに電話';
  }

  @override
  String get line1995 => '生命線（いのちの電話）・中国語';

  @override
  String get line1980 => '張老師（相談ホットライン）・中国語';

  @override
  String get tapToCall => 'タップして発信';

  @override
  String get aiSummaryLabel => 'AI翻訳による要約';

  @override
  String get originalText => '発表機関の原文';

  @override
  String get showOriginalText => '発表機関の原文を見る';

  @override
  String get aiSummaryDisclaimer => 'AI による要約です。内容は発表機関の発表が優先されます。';

  @override
  String get languageBeta => 'Beta';

  @override
  String get languageTitle => '表示言語';

  @override
  String get tabQuake => '地震';

  @override
  String get recentQuakes => '最近の地震';

  @override
  String get historyMap => '過去の地震マップ';

  @override
  String get magnitude => 'マグニチュード';

  @override
  String get depth => '深さ';

  @override
  String depthKm(String km) {
    return '$km km';
  }

  @override
  String get maxIntensity => '最大震度';

  @override
  String maxIntensityIn(String level, String counties) {
    return '最大震度 $level（$counties）';
  }

  @override
  String get originTime => '発生時刻';

  @override
  String get epicenter => '震央';

  @override
  String get reportLink => '中央気象署の地震報告';

  @override
  String get quakeSourceLine => '出典：中央気象署';

  @override
  String get sampleDataNotice => '地震データサービスは準備中です。表示されているのはサンプルデータです。';

  @override
  String historyCaption(int n) {
    return '1996〜2026年、台湾周辺のM4.5以上の地震 $n 件。出典：USGS';
  }

  @override
  String get quakeDetail => '地震の詳細';

  @override
  String get shallow => '深さ 30 km未満';

  @override
  String get intermediate => '深さ 30〜70 km';

  @override
  String get deep => '深さ 70 km超';

  @override
  String get historyDepthKm => '深さ（km）';

  @override
  String get qaRateLimited =>
      '質問回数の上限に達しました。しばらくしてから再度お試しください。緊急時は119に電話してください。';

  @override
  String get qaFailed => '現在お答えできません。しばらくしてから再度お試しください。緊急時は119に電話してください。';

  @override
  String get atLeast => '以上';

  @override
  String shownCount(int n) {
    return '$n 件を表示';
  }

  @override
  String get pushTitle => '通知設定';

  @override
  String get pushPreviewNotice => 'iPhone・iPad 版はまだ通知に対応していません。設定はこの端末に保存されます。';

  @override
  String get pushServiceUnavailable =>
      '通知サービスが一時的に利用できないため、現在は通知が届きません。設定はこの端末に保存されます。しばらくしてからアプリを開き直してください。';

  @override
  String majorAlertsBanner(int n) {
    return '「重大」以上の警報が $n 件発表中です。確認する';
  }

  @override
  String get pushLevels => '通知レベル';

  @override
  String get pushExtremeAlwaysOn =>
      '選択した地域の極めて重大（赤色レベル）の警報は常に通知され、オフにできません。国の緊急警報と同様の扱いです。';

  @override
  String get pushCriticalDesc => '公式の等級が「重大」の警報。AI が「重大」と判定した警報は通知しません。';

  @override
  String get pushCriticalOffWarning => 'オフにすると、選択した地域の重大な警報も通知されません。';

  @override
  String get pushCounties => '通知する地域';

  @override
  String pushCountiesHint(int n) {
    return '$n か所を選択中。複数選択できます。';
  }

  @override
  String get pushSelectAll => 'すべて選択';

  @override
  String get pushClearAll => 'すべて解除';

  @override
  String get pushView => '表示';

  @override
  String get pushAlertEnded => 'この警報は終了しました。';

  @override
  String get pushWebUnavailable =>
      'ウェブ版では現在プッシュ通知を利用できません。重大な警報の通知を受け取るには、アプリをインストールしてください。';

  @override
  String get pushPermissionOff =>
      'この端末では本アプリの通知が許可されていないため、通知は届きません。システム設定で通知をオンにしてください。';

  @override
  String get pushScopeNote =>
      '通知の対象：「極めて重大」の警報と、公式の等級が「重大」の警報のみです。「警戒」「情報」の警報と地震報告は、現在は通知しません。';

  @override
  String get pushCooldownNote =>
      '同じ地域・同じ種類の警報の通知は、30 分間に 1 回までです。「極めて重大」の警報は毎回通知します。';

  @override
  String get affectedCounties => '影響地域';

  @override
  String countyWithLevel(String county, String level) {
    return '$county（$level）';
  }

  @override
  String get call1925 => '1925 中国語';

  @override
  String get crisisCall119 => '119（救急・消防／中国語）';

  @override
  String get row119 => '119 救急・消防（中国語）';

  @override
  String get row1925 => '1925 中国語';

  @override
  String get row1990 => '1990 生活相談（日本語）';

  @override
  String get call1990 => '1990 生活相談（日本語）';

  @override
  String get hoursVary => '受付時間は地域により異なります';

  @override
  String callFailed(String number) {
    return '自動で発信できませんでした。$number に直接電話してください。';
  }

  @override
  String get copy => 'コピー';

  @override
  String get openLinkFailed => 'このリンクを開けませんでした。';

  @override
  String get qaTooLong => '質問は300文字までです。短くしてから送信してください。';

  @override
  String get staleData => 'オフラインのデータを表示しています。最新でない可能性があります。';

  @override
  String get noFreshData => '最新のデータを取得できていません。接続を確認して再試行してください。';

  @override
  String get alertNoLongerActive => 'この警報は解除されたか、内容が更新されました。一覧で最新の情報を確認してください。';

  @override
  String get saveFailed => '設定を保存できませんでした。もう一度お試しください。';

  @override
  String get updateFailed => '更新に失敗しました。以前のデータを表示しています。';

  @override
  String get originalTitle => '原文タイトル';

  @override
  String get historyLoadFailed => '過去の地震データを読み込めませんでした。';

  @override
  String callManual(String number) {
    return '発信アプリが開かない場合は、$number に直接電話してください。';
  }

  @override
  String get settingsLoadFailed => '通知設定を読み込めませんでした。';

  @override
  String get settingsTitle => '設定';

  @override
  String get privacyTitle => 'プライバシー';

  @override
  String get recaptchaNotice => 'このサイトは reCAPTCHA によって保護されています。';

  @override
  String get licensesTitle => 'オープンソースライセンス';

  @override
  String get dataSourcesTitle => 'データの出典';

  @override
  String get srcAlertsTitle => '警報';

  @override
  String get srcAlertsBody =>
      '国家災害防救科技センター（NCDR）が各機関の発表をまとめた公開警報データ（CAP形式）。各警報の詳細画面に元の警報へのリンクがあります。内容は公式発表が優先されます。';

  @override
  String get srcQuakesTitle => '地震';

  @override
  String srcQuakesBody(String significant, String local) {
    return '交通部中央気象署「$significant」（E-A0015-001）と「$local」（E-A0016-001）。政府データオープンライセンス第1版に基づき提供。';
  }

  @override
  String get srcBoundaryTitle => '県市境界（警報詳細の地図）';

  @override
  String get srcBoundaryBody =>
      '内政部国土測絵センター 2025年「直轄市、縣市界線(TWD97經緯度)」（版 1140318）。政府データオープンライセンス第1版に基づき提供。アプリでは簡略化し、影響地域の目安としてのみ使用しています。';

  @override
  String get srcHistoryTitle => '過去の地震マップ';

  @override
  String get srcHistoryBody =>
      '米国地質調査所（USGS）の地震カタログ：1996～2026年の台湾周辺のマグニチュード4.5以上の地震。';

  @override
  String get srcBasemapTitle => '震央位置の背景地図';

  @override
  String get srcBasemapBody =>
      '地図は Google が提供しています。地図を表示すると、端末が Google に直接接続して地図を読み込みます。その通信データは Google のプライバシーポリシーに従って扱われます。';

  @override
  String get openSourcePage => '出典ページを開く';

  @override
  String openSourcePageFor(String title) {
    return '出典ページを開く：$title';
  }

  @override
  String get privacyQa => 'Q&Aの質問は、回答を生成するためにGoogleのGeminiに送信されます。';

  @override
  String get privacyNoStore => 'サーバーは質問の内容を保存せず、質問の種類のみを記録します。';

  @override
  String get privacyIpHash =>
      '利用回数を制限するため、サーバーには接続元 IP アドレスを一方向に変換したコードのみを記録します。元の IP には直接戻せず、約 2 時間後に無効になります。';

  @override
  String get privacyNoLogin => 'アプリはログイン不要で、氏名・電話番号・位置情報を収集しません。';

  @override
  String get privacyPushLocal =>
      '通知設定はこの端末に保存されます。通知を送るため、選んだ地域・警報の等級・表示言語が「トピック」として Google の Firebase Cloud Messaging（FCM）に登録され、iOS の通知はさらに Apple プッシュ通知サービスを経由して届きます。登録内容に氏名や電話番号は含まれず、位置情報も取得しません。ウェブ版には通知機能はありません。';

  @override
  String get privacyMapTiles =>
      '地図には Google マップを使用しており、読み込み時に端末が Google に直接接続します。';

  @override
  String get privacyDataSource =>
      '防災データは台湾の国家災害防救科技センターと中央気象署によるもので、公式発表が優先されます。';

  @override
  String get dataSource => '情報源';

  @override
  String dataSourceDetail(String sender) {
    return '$senderが発表し、国家災害防救科技センター（NCDR）の警報プラットフォーム経由で取得しました。公式発表が優先されます。';
  }

  @override
  String dataSourceDetailShort(String sender) {
    return '$senderが発表し、国家災害防救科技センター（NCDR）の警報プラットフォーム経由で取得しました。';
  }

  @override
  String get expired => '期限切れ';

  @override
  String get alertExpired => 'この警報は有効期限を過ぎています。';

  @override
  String get qaCloudNotice =>
      'すべての質問はクラウドに送信され、Google Geminiが回答を生成します。タップしてプライバシーについて確認できます。';

  @override
  String get qaCloudNoticeShort => '質問はクラウドへ送信 · プライバシー';

  @override
  String get qaRotatePortrait => '防災Q&Aは縦向きでご利用ください';

  @override
  String get levelUnrated => '等級なし';

  @override
  String get recentlyEnded => '過去24時間に終了した警報';

  @override
  String get ended => '終了';

  @override
  String endedAtShort(String time) {
    return '$time 終了';
  }

  @override
  String alertEnded(String time) {
    return 'この警報は $time に終了しました。';
  }

  @override
  String get noRecentlyEnded => '過去24時間に終了した警報はありません。';

  @override
  String get updating => '更新中';

  @override
  String cwaAttribution(String year, String dataset, String datasetId) {
    return '提供機関：交通部中央気象署 $year年「$dataset」（$datasetId）。政府データオープンライセンス第1版に基づき公開。';
  }

  @override
  String cwaAttributionNoYear(String dataset, String datasetId) {
    return '提供機関：交通部中央気象署「$dataset」（$datasetId）。政府データオープンライセンス第1版に基づき公開。';
  }

  @override
  String get datasetSignificant => '顕著有感地震報告';

  @override
  String get datasetLocal => '小区域有感地震報告';

  @override
  String get datasetQuakes => '顕著有感地震報告・小区域有感地震報告';

  @override
  String get quakeReportDelay =>
      '地震報告は震度を人手で確認してから、発生の数分後に発表されます。揺れを感じた直後は、まだ表示されない場合があります。';

  @override
  String get localQuake => '小区域';

  @override
  String get byCounty => '地域別の警報';

  @override
  String countyCount(String county, int n) {
    return '$county $n件';
  }

  @override
  String get qaSearching => '検索しています…';

  @override
  String withLabel(String text, String label) {
    return '$text（$label）';
  }

  @override
  String groupedTitle(String title, int n) {
    return '$title：$n件';
  }

  @override
  String get groupedHint => '同じ通報に複数の項目があります。タップして各項目を確認できます。';

  @override
  String syncFailedSince(String time) {
    return '直近の更新に失敗しました。最終成功：$time';
  }

  @override
  String get syncFailedNever => '直近の更新に失敗しました。まだ一度も同期に成功していません。';

  @override
  String get openDataLicense => '政府データオープンライセンス';

  @override
  String get noFilteredAlerts => '現在の絞り込み条件に合う警報はありません。';

  @override
  String get noLongerMatchesFilter => 'この警報は現在の絞り込み条件に該当しなくなりました。';

  @override
  String get qaCrisisLinesShown => '入力欄の上に相談窓口の電話ボタンがあります。';

  @override
  String get qaReport => 'この回答を報告';

  @override
  String get qaReportReason => '理由';

  @override
  String get qaReportReasonIncorrect => '不正確';

  @override
  String get qaReportReasonOutdated => '情報が古い、または公式情報と異なる';

  @override
  String get qaReportReasonOffensive => '不適切または不快';

  @override
  String get qaReportReasonOther => 'その他';

  @override
  String get qaReportNote => '詳細（任意）';

  @override
  String get qaReportNotice =>
      'この報告では、質問と回答が開発者に送信され、回答の改善のため 90 日間保存されます。詳細欄に氏名や電話番号などの個人情報を書かないでください。';

  @override
  String get qaReportSend => '送信';

  @override
  String get qaReportThanks => '報告を受け付けました。ありがとうございます。';

  @override
  String get qaReportFailed => '報告を送信できませんでした。しばらくしてからもう一度お試しください。';

  @override
  String get qaReportRateLimited => '報告が多すぎます。しばらくしてからもう一度お試しください。';

  @override
  String get qaReportDailyFull =>
      '本日の報告受付数が上限に達しました。プライバシーに関する説明に記載の連絡先までメールでお知らせください。';

  @override
  String qaReportDailyFullEmail(String email) {
    return '本日の報告受付数が上限に達しました。$email までメールでお知らせください。';
  }

  @override
  String get aboutBody1 =>
      '防災速報は、行政機関が発表し現在も有効な災害警報を一つの画面にまとめ、地震情報、防災Q&A、災害への備えの情報も提供します。';

  @override
  String get aboutBody2 =>
      '本サービスは個人が開発した非公式のサービスで、政府機関のサービスではなく、データ提供機関とは提携・所属関係はありません。';

  @override
  String get aboutContact => 'お問い合わせ';

  @override
  String get aboutBuiltWithTitle => '使用技術';

  @override
  String get aboutBuiltWithBody =>
      '本アプリは次の技術を使用して開発しています：Google Cloud、Firebase、Google マップ、Gemini、Flutter、Google Antigravity。';

  @override
  String get aboutTrademarks => 'これらの名称および Google は Google LLC の商標です。';

  @override
  String get aboutUsTitle => '私たちについて';

  @override
  String get aboutBody3 =>
      '警報の内容については、発表機関の公式発表が優先されます。緊急時は 119 または 110 に直接電話してください。';

  @override
  String get backToGroup => 'グループに戻る';
}
