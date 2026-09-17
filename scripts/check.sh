#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-"$PROJECT_DIR/work/tools/Godot.app/Contents/MacOS/Godot"}
cd "$PROJECT_DIR"
mkdir -p work/check
run_check() {
  name=$1
  shift
  if ! "$GODOT_BIN" --headless --path "$PROJECT_DIR" "$@" > "work/check/$name.log" 2>&1; then
    cat "work/check/$name.log"
    exit 1
  fi
  if grep -E 'SCRIPT ERROR|ERROR:|FAIL |WARNING:' "work/check/$name.log"; then
    cat "work/check/$name.log"
    exit 1
  fi
  printf '%s: PASS\n' "$name"
}
run_check import --editor --import
run_check combat --script tests/run.gd
run_check presentation --script tests/presentation.gd
run_check updates --script tests/game_update.gd
run_check aim-input --script tests/aim_input.gd
run_check integration --script tests/integration.gd
run_check battle-rules --script tests/battle_rules.gd
run_check battle-integration --script tests/battle_integration.gd
run_check world-models --script tests/world_models.gd
run_check world-collisions --script tests/world_collisions.gd
run_check modes --script tests/modes.gd
run_check enemy-simulation --fixed-fps 60 --script tests/enemy_simulation.gd
run_check startup --quit-after 90
