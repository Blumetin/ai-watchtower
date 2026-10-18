library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const counties = <String, (String zh, String en, String ja)>{
  'kee': ('基隆市', 'Keelung City', '基隆市'),
  'tpe': ('臺北市', 'Taipei City', '台北市'),
  'nwt': ('新北市', 'New Taipei City', '新北市'),
  'tao': ('桃園市', 'Taoyuan City', '桃園市'),
  'hsz': ('新竹市', 'Hsinchu City', '新竹市'),
  'hsq': ('新竹縣', 'Hsinchu County', '新竹県'),
  'mia': ('苗栗縣', 'Miaoli County', '苗栗県'),
  'txg': ('臺中市', 'Taichung City', '台中市'),
  'cha': ('彰化縣', 'Changhua County', '彰化県'),
  'nan': ('南投縣', 'Nantou County', '南投県'),
  'yun': ('雲林縣', 'Yunlin County', '雲林県'),
  'cyi': ('嘉義市', 'Chiayi City', '嘉義市'),
  'cyq': ('嘉義縣', 'Chiayi County', '嘉義県'),
  'tnn': ('臺南市', 'Tainan City', '台南市'),
  'khh': ('高雄市', 'Kaohsiung City', '高雄市'),
  'pif': ('屏東縣', 'Pingtung County', '屏東県'),
  'ila': ('宜蘭縣', 'Yilan County', '宜蘭県'),
  'hua': ('花蓮縣', 'Hualien County', '花蓮県'),
  'ttt': ('臺東縣', 'Taitung County', '台東県'),
  'pen': ('澎湖縣', 'Penghu County', '澎湖県'),
  'kin': ('金門縣', 'Kinmen County', '金門県'),
  'lie': ('連江縣', 'Lienchiang County', '連江県'),
};

String countyName(String code, String lang) {
  final c = counties[code];
  if (c == null) return code;
  return switch (lang) {
    'en' => c.$2,
    'ja' => c.$3,
    _ => c.$1,
  };
}

String countyNameFromZh(String zh, String lang) {
  final norm = zh.replaceAll('台', '臺');
  for (final MapEntry(:key, :value) in counties.entries) {
    if (value.$1 == norm) return countyName(key, lang);
  }
  return zh;
}

class PushPrefs {
  final Set<String> counties;
  final bool critical;

  final bool test;
  const PushPrefs({
    this.counties = const {},
    this.critical = true,
    this.test = false,
  });

  PushPrefs copyWith({Set<String>? counties, bool? critical, bool? test}) =>
      PushPrefs(
        counties: counties ?? this.counties,
        critical: critical ?? this.critical,
        test: test ?? this.test,
      );

  Set<String> topics(String lang) {
    final code = lang.split(RegExp('[-_]')).first.toLowerCase();
    lang = const {'zh', 'en', 'ja'}.contains(code) ? code : 'en';
    final prefix = test ? 'test' : 'alert';
    return {
      for (final c in counties) ...[
        '${prefix}_${c}_extreme_$lang',
        if (critical) '${prefix}_${c}_critical_$lang',
      ],
    };
  }
}


abstract class PushPrefsStore {
  Future<PushPrefs> load();
  Future<void> save(PushPrefs prefs);
}


class LocalPushPrefsStore implements PushPrefsStore {
  static const _kCounties = 'push.counties';
  static const _kCritical = 'push.critical';
  static const _kTest = 'push.test';

  @override
  
  Future<PushPrefs> load() async {
    final sp = await SharedPreferences.getInstance();
    await sp.reload();
    return PushPrefs(
      counties: {...?sp.getStringList(_kCounties)}
          .where(counties.containsKey)
          .toSet(),
      critical: sp.getBool(_kCritical) ?? true,
      test: kDebugMode && (sp.getBool(_kTest) ?? false),
    );
  }

  @override
  Future<void> save(PushPrefs prefs) async {
    final sp = await SharedPreferences.getInstance();
    final ok = await Future.wait([
      sp.setStringList(_kCounties, prefs.counties.toList()..sort()),
      sp.setBool(_kCritical, prefs.critical),
      sp.setBool(_kTest, prefs.test),
    ]);
    if (ok.contains(false)) throw StateError('push prefs not saved');
  }
}
