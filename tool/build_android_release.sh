#!/bin/sh
set -e
stop() { echo "$1，停止建置" >&2; exit 1; }
target=apk
case "$1" in
  apk|appbundle) target="$1"; shift ;;
  ''|-*) ;;
  *) stop "第一個參數要是 apk 或 appbundle" ;;
esac
if [ -n "$APP_CHECK_ANDROID_DEBUG" ]; then stop "正式版不允許 APP_CHECK_ANDROID_DEBUG"; fi
if [ -n "$APP_CHECK_DEBUG_TOKEN" ]; then stop "正式版不允許 APP_CHECK_DEBUG_TOKEN"; fi
if [ -n "$DEMO_SCENARIO_UID" ]; then stop "正式版不允許 DEMO_SCENARIO_UID"; fi
for a in "$@"; do
  case "$a" in
    *APP_CHECK_ANDROID_DEBUG*) stop "正式版不允許 APP_CHECK_ANDROID_DEBUG" ;;
    *DEMO_SCENARIO_UID*) stop "正式版不允許 DEMO_SCENARIO_UID（錄影情境示意只給非正式建置，主控 10/4）" ;;
    *APP_CHECK_DEBUG_TOKEN*) stop "正式版不允許 APP_CHECK_DEBUG_TOKEN（固定除錯權杖只給除錯版，資安 10/3）" ;;
    --dart-define-from-file*) stop "正式版不允許 --dart-define-from-file（無法檢查檔案內容）" ;;
    --debug*|--profile*) stop "正式版只能用 --release" ;;
  esac
done
cd "$(dirname "$0")/.." || stop "無法切換到專案根目錄"
flutter build "$target" "$@" --release --dart-define=APP_CHECK_ANDROID_DEBUG=false --dart-define=APP_CHECK_DEBUG_TOKEN= --dart-define=DEMO_SCENARIO_UID=
