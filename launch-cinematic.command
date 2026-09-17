#!/bin/sh
# Optional Forward+ sample. launch.command keeps the compatibility renderer.
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$PROJECT_DIR/launch.command" --rendering-method forward_plus "$@"
