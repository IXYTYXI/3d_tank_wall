#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PACKAGE_VERSION=$(awk -F'"' '/^config\/version=/ {print $2}' "$PROJECT_DIR/project.godot")
APP="$PROJECT_DIR/outputs/macos/SteelFront-$PACKAGE_VERSION.app"
BIN="$APP/Contents/MacOS/钢铁战场"
LOG_DIR="$PROJECT_DIR/work/package"
mkdir -p "$LOG_DIR"
codesign --verify --deep --strict "$APP"
lipo "$BIN" -verify_arch x86_64 arm64
# Run outside the source project, using only the app's embedded PCK resources.
TEST_DIR=$(mktemp -d "$PROJECT_DIR/work/package/run.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM
cd "$TEST_DIR"
run_check() {
  name=$1
  shift
  if ! "$BIN" --headless "$@" > "$LOG_DIR/$name.log" 2>&1; then
    cat "$LOG_DIR/$name.log"
    exit 1
  fi
  if grep -E 'SCRIPT ERROR|ERROR:|FAIL |WARNING:' "$LOG_DIR/$name.log"; then
    cat "$LOG_DIR/$name.log"
    exit 1
  fi
  printf '%s: PASS\n' "$name"
}
run_check standalone --quit-after 90
# Release templates intentionally reject external script overrides. Verify their
# compiled PCK resources with the matching editor, without using source resources.
GODOT_BIN=${GODOT_BIN:-"$PROJECT_DIR/work/tools/Godot.app/Contents/MacOS/Godot"}
for suite in game_update aim_input modes battle_integration world_models world_collisions; do
  "$GODOT_BIN" --headless --main-pack "$APP/Contents/Resources/钢铁战场.pck" --script "$PROJECT_DIR/tests/$suite.gd" > "$LOG_DIR/exported-$suite.log" 2>&1
  if grep -E 'SCRIPT ERROR|ERROR:|FAIL |WARNING:' "$LOG_DIR/exported-$suite.log"; then
    exit 1
  fi
  grep -q 'PASS ' "$LOG_DIR/exported-$suite.log"
  printf 'exported-%s: PASS\n' "$suite"
done
cd "$PROJECT_DIR/outputs/macos"
LC_ALL=C shasum -a 256 -c SHA256SUMS.txt
