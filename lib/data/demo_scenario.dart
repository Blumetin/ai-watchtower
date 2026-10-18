import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const _uid = String.fromEnvironment('DEMO_SCENARIO_UID');

const bool demoScenarioEnabled = !kReleaseMode && _uid != '';

const String demoScenarioUid = demoScenarioEnabled ? _uid : '';

Map<String, dynamic> asScenarioActive(Map<String, dynamic> m) =>
    {...m, 'status': 'active'}
      ..remove('ended_at')
      ..remove('expires');

const _noticeStyle = String.fromEnvironment(
  'DEMO_SCENARIO_NOTICE',
  defaultValue: 'dramatization',
);
const _notices = {
  'dramatization': {
    'zh': '情境示意；示警內容取自中央氣象署過去實際發布的示警',
    'en': "Dramatization. The alert shown is a past alert actually issued by Taiwan's Central Weather Administration.",
    'ja': 'イメージ映像です。表示の警報は、台湾の中央気象署が過去に実際に発表したものです。',
  },
  'replay': {
    'zh': '示範重播：這是臺灣中央氣象署過去實際發布的示警，為了示範推播通知，以生效中的狀態呈現。',
    'en': "Replay for demo: a real past alert issued by Taiwan's Central Weather Administration, shown as active to demonstrate the notification.",
    'ja': 'デモ用の再現です。台湾の中央気象署が過去に実際に発表した警報を、通知の仕組みを示すため、発表中の状態で表示しています。',
  },
};

String _noticeText(String lang) {
  final set = _notices[_noticeStyle];
  if (set == null) return '[DEMO_SCENARIO_NOTICE 不認得：$_noticeStyle]';
  return set[lang] ??
      (_noticeStyle == 'dramatization' ? set['en']! : '[缺少 $lang 的 replay 字卡]');
}

Widget withDemoScenarioNotice(BuildContext context, Widget child) {
  if (!demoScenarioEnabled) return child;
  final lang = Localizations.localeOf(context).languageCode;
  return Column(
    children: [
      Expanded(
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: child,
        ),
      ),
      Material(
        color: const Color(0xFF37474F),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              _noticeText(lang),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ),
    ],
  );
}
