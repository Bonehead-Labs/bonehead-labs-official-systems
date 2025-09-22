#!/usr/bin/env bash
set -euo pipefail

# Executes all GUT tests in headless mode using the CLI runner.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
GUT_CLI="res://addons/gut/gut_cmdln.gd"

if ! command -v "${GODOT_BIN}" >/dev/null 2>&1; then
  echo "[run_gut_tests] Unable to find Godot executable '${GODOT_BIN}'." >&2
  echo "Set GODOT_BIN to the path of your Godot 4.5 binary." >&2
  exit 1
fi

cd "${PROJECT_ROOT}"

mapfile -t GUT_DIRS < <(find . -type d -name UnitTests | sort)
if [ "${#GUT_DIRS[@]}" -eq 0 ]; then
  echo "[run_gut_tests] No UnitTests directories discovered." >&2
  exit 0
fi

CLI_ARGS=()
for dir in "${GUT_DIRS[@]}"; do
  # Remove leading ./ for res:// conversion
  clean_dir="${dir#./}"
  CLI_ARGS+=("-gdir=res://${clean_dir}")
  CLI_ARGS+=("-ginclude_subdirs=true")
fi

# Ensure deterministic ordering for reproducible results.
export GUT_SORT_TESTS=1

set -x
"${GODOT_BIN}" \
  --headless \
  --path "${PROJECT_ROOT}" \
  --script "${GUT_CLI}" \
  "${CLI_ARGS[@]}" \
  -gexit=true \
  -gignore_pause=true
