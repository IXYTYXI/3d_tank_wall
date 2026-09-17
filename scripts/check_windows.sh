#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-"$PROJECT_DIR/work/tools/Godot.app/Contents/MacOS/Godot"}
PACKAGE_VERSION=$(awk -F'"' '/^config\/version=/ {print $2}' "$PROJECT_DIR/project.godot")
LOG_DIR="$PROJECT_DIR/work/package"
mkdir -p "$LOG_DIR"
TEST_DIR=$(mktemp -d "$LOG_DIR/windows-check.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM
python3 - "$PROJECT_DIR/outputs/windows/SteelFront-$PACKAGE_VERSION-Windows-x64.zip" "$TEST_DIR" <<'PY'
import pathlib, struct, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    assert z.testzip() is None, 'ZIP CRC failure'
    names = z.namelist()
    assert len(names) == 7, names
    for required in ('SteelFront.exe','SteelFront.pck','HighQuality.cmd','安装与玩法说明.txt','Licenses/Godot-LICENSE.txt','Licenses/Godot-COPYRIGHT.txt','Licenses/NotoSansSC-OFL.txt'):
        assert any(n.endswith('/'+required) for n in names), required
    exe = z.read(next(n for n in names if n.endswith('/SteelFront.exe')))
    assert exe[:2] == b'MZ'
    offset = struct.unpack_from('<I',exe,0x3c)[0]
    assert exe[offset:offset+4] == b'PE\0\0'
    assert struct.unpack_from('<H',exe,offset+4)[0] == 0x8664, 'Not x86_64'
    assert struct.unpack_from('<H',exe,offset+24)[0] == 0x20b, 'Not PE32+'
    z.extractall(sys.argv[2])
print('Windows PE architecture, ZIP integrity and package contents: PASS')
PY
cd "$TEST_DIR"
PCK="$TEST_DIR/SteelFront-$PACKAGE_VERSION-Windows-x64/SteelFront.pck"
"$GODOT_BIN" --headless --main-pack "$PCK" --quit-after 90 > "$LOG_DIR/windows-resources-startup.log" 2>&1
if grep -E 'SCRIPT ERROR|ERROR:|FAIL |WARNING:' "$LOG_DIR/windows-resources-startup.log"; then exit 1; fi
for suite in game_update aim_input modes battle_integration world_models world_collisions; do
  "$GODOT_BIN" --headless --main-pack "$PCK" --script "$PROJECT_DIR/tests/$suite.gd" > "$LOG_DIR/windows-$suite.log" 2>&1
  if grep -E 'SCRIPT ERROR|ERROR:|FAIL |WARNING:' "$LOG_DIR/windows-$suite.log"; then exit 1; fi
  grep -q 'PASS ' "$LOG_DIR/windows-$suite.log"
  printf 'Windows exported resources %s: PASS\n' "$suite"
done
cd "$PROJECT_DIR/outputs/windows"
LC_ALL=C shasum -a 256 -c SHA256SUMS.txt
printf 'Cross-platform resource checks complete. Windows executable runtime is NOT tested by this script.\n'
