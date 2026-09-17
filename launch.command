#!/bin/zsh
set -eu
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT_BIN="$PROJECT_DIR/work/tools/Godot.app/Contents/MacOS/Godot"
if [[ ! -x "$GODOT_BIN" ]]; then
  print '未找到本地 Godot。请用 Godot 4.7.2 或更新兼容版本打开 project.godot。'
  exit 1
fi
exec "$GODOT_BIN" --path "$PROJECT_DIR" "$@"
