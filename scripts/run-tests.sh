#!/usr/bin/env bash
# Builds and runs the unit tests (build.edn :tests). Arguments go to the test
# program: --list, --run NAME, --no-skip.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/scripts/env.sh"
cd "$ROOT"
mkdir -p build
nucleus test -- "$@"
