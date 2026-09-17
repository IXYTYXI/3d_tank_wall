#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-"$PROJECT_DIR/work/tools/Godot.app/Contents/MacOS/Godot"}
cd "$PROJECT_DIR"
if [ ! -f work/export-templates/macos.zip ]; then
  echo 'Missing official macOS export template: work/export-templates/macos.zip' >&2
  exit 1
fi
mkdir -p outputs/macos work/package
touch work/.gdignore outputs/.gdignore
STAGING=$(mktemp -d "$PROJECT_DIR/work/package/staging.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT HUP INT TERM
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --editor --import > work/package/import.log 2>&1
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release macOS "$STAGING/钢铁战场.app" > work/package/export.log 2>&1
if grep -E 'SCRIPT ERROR|ERROR:|Export failed' work/package/import.log work/package/export.log; then
  exit 1
fi
codesign --verify --deep --strict "$STAGING/钢铁战场.app"
ln -s /Applications "$STAGING/Applications"
cp docs/mac-install.txt "$STAGING/安装与玩法说明.txt"
mkdir "$STAGING/Licenses"
cp docs/licenses/Godot-LICENSE.txt docs/licenses/Godot-COPYRIGHT.txt "$STAGING/Licenses/"
cp assets/fonts/OFL.txt "$STAGING/Licenses/NotoSansSC-OFL.txt"
# Keep a separately launchable copy for export validation.
ditto "$STAGING/钢铁战场.app" outputs/macos/SteelFront.app
hdiutil create -ov -format UDZO -fs HFS+ -volname '钢铁战场 0.2.0' -srcfolder "$STAGING" outputs/macos/SteelFront-0.2.0-macOS-universal.dmg
hdiutil verify outputs/macos/SteelFront-0.2.0-macOS-universal.dmg
cd outputs/macos
LC_ALL=C shasum -a 256 SteelFront-0.2.0-macOS-universal.dmg > SHA256SUMS.txt
cat SHA256SUMS.txt
