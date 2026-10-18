library;

const _categories = <String, (String en, String ja)>{
  '颱風': ('Typhoon', '台風'),
  '高溫': ('High Temperature', '高温'),
  '降雨': ('Rainfall', '降雨'),
  '雷雨': ('Thunderstorm', '雷雨'),
  '強風': ('Strong Wind', '強風'),
  '空氣品質': ('Air Quality', '大気質'),
  '地震': ('Earthquake', '地震'),
  '海嘯': ('Tsunami', '津波'),
  '水庫放流': ('Reservoir Discharge', 'ダム放流'),
  '淹水': ('Flooding', '浸水'),
  '淹水感測': ('Flood Sensor Alert', '浸水センサー'),
  '區排警戒': ('Regional Drainage Alert', '排水路警戒'),
  '河川高水位': ('High River Water Level', '河川の高水位'),
  '交流道下地方連絡道淹水': ('Flooding on Interchange Access Roads', 'IC連絡道路の浸水'),
  '土石流及大規模崩塌': ('Debris Flow & Large-scale Landslide', '土石流・大規模崩壊'),
  '火災': ('Fire', '火災'),
  '海洋污染': ('Marine Pollution', '海洋汚染'),
  '消防安全檢查重大不合格場所': ('Premises Failing Fire Safety Inspection', '消防検査の重大不適合施設'),
  '鐵路事故': ('Railway Incident', '鉄道事故'),
  '道路封閉': ('Road Closure', '道路閉鎖'),
  '高速公路路況事件': ('Freeway Traffic Incident', '高速道路の交通情報'),
  '停水': ('Water Outage', '断水'),
  '行動電話中斷': ('Mobile Service Outage', '携帯電話の通信障害'),
  '停班停課': ('Work & School Closures', '休業・休校'),
  '疏散避難': ('Evacuation', '避難'),
  '國家森林遊樂區': ('National Forest Recreation Area Notice', '国家森林遊楽区のお知らせ'),
  '急門診通報': ('Hospital Service Notice', '病院の診療案内'),
};

const _senders = <String, (String en, String ja)>{
  '中央氣象署': ('Central Weather Administration', '中央気象署'),
  '水利署': ('Water Resources Agency', '水利署'),
  '內政部消防署': ('National Fire Agency', '内政部消防署'),
  '衛生福利部': ('Ministry of Health and Welfare', '衛生福利部'),
  '台灣自來水公司': ('Taiwan Water Corporation', '台湾自来水公司'),
  '海洋保育署': ('Ocean Conservation Administration', '海洋保育署'),
  '交通部高速公路局': ('Freeway Bureau, MOTC', '交通部高速公路局'),
  '臺鐵公司': ('Taiwan Railway Corporation', '台湾鉄路公司'),
};

String _pick(Map<String, (String, String)> table, String zh, String lang) {
  final row = table[zh];
  if (row == null) return zh;
  return switch (lang) {
    'en' => row.$1,
    'ja' => row.$2,
    _ => zh,
  };
}

String categoryName(String zh, String lang) => _pick(_categories, zh, lang);

String senderName(String zh, String lang) => _pick(_senders, zh, lang);

String titleText(
  String title,
  String rawCategory,
  String lang, {
  String? fallback,
}) {
  if (lang == 'zh') return title;
  return _categories.containsKey(rawCategory)
      ? categoryName(rawCategory, lang)
      : (fallback ?? title);
}
