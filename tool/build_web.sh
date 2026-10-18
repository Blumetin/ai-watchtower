#!/bin/sh
set -e
if [ -z "$APP_CHECK_SITE_KEY" ]; then
  echo "APP_CHECK_SITE_KEY 未設定，停止建置" >&2
  exit 1
fi
if [ -n "$DEMO_SCENARIO_UID" ]; then echo "網頁正式建置不允許 DEMO_SCENARIO_UID，停止建置" >&2; exit 1; fi
for a in "$@"; do
  case "$a" in
    *DEMO_SCENARIO_UID*) echo "網頁正式建置不允許 DEMO_SCENARIO_UID，停止建置" >&2; exit 1 ;;
    --debug*|--profile*) echo "網頁正式建置只能用 --release，停止建置" >&2; exit 1 ;;
    --dart-define-from-file*) echo "網頁正式建置不允許 --dart-define-from-file（無法檢查檔案內容，資安 10/4 建議）" >&2; exit 1 ;;
    --wasm*) echo "網頁正式建置只支援 dart2js（主程式改名與長快取不涵蓋 --wasm 產物）" >&2; exit 1 ;;
  esac
done
MAPS_KEYS="${WATCHTOWER_MAPS_KEYS:-$HOME/.config/watchtower/maps_keys.properties}"
[ -f "$MAPS_KEYS" ] || { echo "找不到 Google 地圖金鑰檔：$MAPS_KEYS，停止建置" >&2; exit 1; }
MAPS_API_KEY_WEB=$(sed -n 's/^MAPS_API_KEY_WEB=//p' "$MAPS_KEYS" | tail -1 | tr -d '\r[:space:]')
[ -n "$MAPS_API_KEY_WEB" ] || { echo "金鑰檔裡沒有 MAPS_API_KEY_WEB，停止建置" >&2; exit 1; }
cd "$(dirname "$0")/.." || exit 1
flutter build web --release \
  --dart-define=APP_CHECK_SITE_KEY="$APP_CHECK_SITE_KEY" \
  --dart-define=APP_CHECK_ENTERPRISE="${APP_CHECK_ENTERPRISE:-true}" \
  "$@" \
  --dart-define=DEMO_SCENARIO_UID=
MAPS_API_KEY_WEB="$MAPS_API_KEY_WEB" python3 - <<'PY' || exit 1
import json, os, urllib.parse
p = 'build/web/index.html'
s = open(p, encoding='utf-8').read()
key = os.environ['MAPS_API_KEY_WEB']
boot = '<script src="flutter_bootstrap.js" async></script>'
# 檢查用明確 raise，不用 assert（python -O 會略過，Codex 審查）。
if s.count('</head>') != 1:
    raise SystemExit('index.html 結構不符，停止')
if s.count(boot) != 1:
    raise SystemExit('index.html 找不到唯一的 flutter_bootstrap.js，停止')
if 'window.watchtowerLang = ' not in s:
    raise SystemExit('index.html 沒有介面語言，停止')
if 'maps.googleapis.com/maps/api/js' in s:
    raise SystemExit('已注入過，停止')
base = 'https://maps.googleapis.com/maps/api/js?key=' + urllib.parse.quote(key, safe='')
tag = """<script>
    (function () {
      var lang = window.watchtowerLang;
      if (lang !== 'zh' && lang !== 'ja') lang = 'en';
      window.watchtowerMapsLang = lang;
      var started = false;
      function boot() {
        if (started) return;
        started = true;
        var b = document.createElement('script');
        b.src = 'flutter_bootstrap.js';
        b.async = true;
        document.body.appendChild(b);
      }
      function ready() {
        if (document.body) boot();
        else document.addEventListener('DOMContentLoaded', boot);
      }
      var m = document.createElement('script');
      m.src = MAPS_BASE + '&language=' + {zh: 'zh-TW', ja: 'ja', en: 'en'}[lang];
      m.onload = ready;
      m.onerror = ready;
      document.head.appendChild(m);
    })();
  </script>
""".replace('MAPS_BASE', json.dumps(base))
s = s.replace(boot, '').replace('</head>', tag + '</head>')
open(p, 'w', encoding='utf-8').write(s)
print('已注入 Google 地圖腳本到 build/web/index.html')
PY
python3 - <<'PY' || exit 1
import glob, hashlib, json, os, re, sys

def stop(msg):
    raise SystemExit('主程式改名：' + msg + '，停止建置')

d = 'build/web'
src = os.path.join(d, 'main.dart.js')
boot = os.path.join(d, 'flutter_bootstrap.js')
if not os.path.isfile(src):
    stop('找不到 main.dart.js')
if glob.glob(os.path.join(d, '**', '*.part.js'), recursive=True):
    stop('有分段檔（*.part.js），改名規則未涵蓋')
if glob.glob(os.path.join(d, 'main.dart.wasm')) or glob.glob(os.path.join(d, '*.mjs')):
    stop('有 wasm 編譯產物（main.dart.wasm／*.mjs）')
for f in glob.glob(os.path.join(d, 'main.*')):
    name = os.path.basename(f)
    if name != 'main.dart.js' and not re.fullmatch(r'main\.[0-9a-f]{12}\.dart\.js', name):
        stop('有不認得的主程式相關檔 ' + name)
s = open(boot, encoding='utf-8').read()
m = re.search(r'"builds":(\[.*?\])', s)
if not m:
    stop('flutter_bootstrap.js 找不到 buildConfig')
try:
    builds = [b for b in json.loads(m.group(1)) if b]
except ValueError:
    stop('buildConfig 格式不符')
if len(builds) != 1 or builds[0].get('compileTarget') != 'dart2js' or builds[0].get('mainJsPath') != 'main.dart.js':
    stop('buildConfig 不是單一 dart2js 入口 main.dart.js')
if s.count('"main.dart.js"') != 3 or s.count('main.dart.js') != 3:
    stop('flutter_bootstrap.js 的 main.dart.js 引用不是 3 處')
# 其他文字產物不得引用舊檔名；flutter.js 例外（index.html 不載入它，loader 已內嵌在 flutter_bootstrap.js）。
for f in glob.glob(os.path.join(d, '**', '*'), recursive=True):
    if not os.path.isfile(f) or f in (src, boot, os.path.join(d, 'flutter.js')):
        continue
    if os.path.splitext(f)[1] not in ('.js', '.html', '.json', '.mjs'):
        continue
    if 'main.dart.js' in open(f, encoding='utf-8', errors='ignore').read():
        stop(os.path.relpath(f, d) + ' 也引用 main.dart.js')
digest = hashlib.sha256(open(src, 'rb').read()).hexdigest()[:12]
new = 'main.' + digest + '.dart.js'
new_boot = s.replace('"main.dart.js"', '"' + new + '"')
if 'main.dart.js' in new_boot:
    stop('flutter_bootstrap.js 換名後仍有舊檔名')
# 檢查都過了才動檔案：清掉上次的雜湊檔、改名主程式、再替換 bootstrap（先寫暫存檔）。
for f in glob.glob(os.path.join(d, 'main.*.dart.js')):
    if re.fullmatch(r'main\.[0-9a-f]{12}\.dart\.js', os.path.basename(f)):
        os.remove(f)
tmp = boot + '.tmp'
open(tmp, 'w', encoding='utf-8').write(new_boot)
os.rename(src, os.path.join(d, new))
os.replace(tmp, boot)
if not os.path.isfile(os.path.join(d, new)) or os.path.exists(src):
    stop('改名失敗')
if len(glob.glob(os.path.join(d, 'main.*.dart.js'))) != 1:
    stop('主程式檔不只一個')
print('主程式檔名：' + new)
PY
