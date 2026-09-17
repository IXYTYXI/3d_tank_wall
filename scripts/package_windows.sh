#!/bin/sh
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-"$PROJECT_DIR/work/tools/Godot.app/Contents/MacOS/Godot"}
cd "$PROJECT_DIR"
PACKAGE_VERSION=$(awk -F'"' '/^config\/version=/ {print $2}' project.godot)
test -f work/export-templates/windows_release_x86_64.exe
mkdir -p outputs/windows work/package
touch work/.gdignore outputs/.gdignore
STAGING=$(mktemp -d "$PROJECT_DIR/work/package/windows.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT HUP INT TERM
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --editor --import > work/package/windows-import.log 2>&1
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release 'Windows Desktop' "$STAGING/SteelFront.exe" > work/package/windows-export.log 2>&1
if grep -E 'SCRIPT ERROR|ERROR:|Export failed|WARNING:' work/package/windows-import.log work/package/windows-export.log; then
  exit 1
fi
cp docs/windows-install.txt "$STAGING/安装与玩法说明.txt"
mkdir "$STAGING/Licenses"
cp docs/licenses/Godot-LICENSE.txt docs/licenses/Godot-COPYRIGHT.txt "$STAGING/Licenses/"
cp assets/fonts/OFL.txt "$STAGING/Licenses/NotoSansSC-OFL.txt"
python3 - "$STAGING" "$PROJECT_DIR/outputs/windows" "$PACKAGE_VERSION" <<'PY'
import hashlib, pathlib, sys, zipfile
staging, output = map(pathlib.Path, sys.argv[1:3])
name = f'SteelFront-{sys.argv[3]}-Windows-x64'
archive = output / (name + '.zip')
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for p in sorted(staging.rglob('*')):
        if p.is_file():
            z.write(p, pathlib.PurePosixPath(name) / p.relative_to(staging))
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(output / 'SHA256SUMS.txt').write_text(f'{digest}  {archive.name}\n')
print(f'{digest}  {archive.name}')
PY
