#!/bin/sh
set -e
SRC="${WEB_BUILD_DIR:-$HOME/dev/watchtower_app/build/web}"
DST="$(cd "$(dirname "$0")/.." && pwd)/public"

[ -f "$SRC/index.html" ] || { echo "找不到建置產物：$SRC（請前端先跑 flutter build web）"; exit 1; }
rsync -a --delete "$SRC/" "$DST/"
echo "已同步 $(find "$DST" -type f | wc -l | tr -d ' ') 個檔案，來源時間 $(date -r "$SRC/index.html" '+%Y-%m-%d %H:%M')"

case "$1" in
  deploy) firebase hosting:channel:deploy internal --expires 30d ;;
  live)   printf '即將部署到正式站 ai-watchtower-tw.web.app（會重新公開）。確定已取得使用者同意？輸入 yes 繼續：'
          read ans; [ "$ans" = "yes" ] && firebase deploy --only hosting || echo "已取消" ;;
esac
