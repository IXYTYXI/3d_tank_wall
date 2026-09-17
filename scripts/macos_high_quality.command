#!/bin/sh
set -eu
LAUNCHER_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP="$LAUNCHER_DIR/钢铁战场.app"
if [ ! -d "$APP" ]; then APP="/Applications/钢铁战场.app"; fi
if [ ! -d "$APP" ]; then
  echo '请先将钢铁战场.app 安装到 Applications，再运行本脚本。'
  exit 1
fi
exec /usr/bin/open -n "$APP" --args --rendering-method forward_plus
