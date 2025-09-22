#!/usr/bin/env bash
set -euo pipefail

# Runs Godot script checks in headless mode. Requires Godot 4.5+ binary.
# Configure GODOT_BIN env var if godot binary is not on PATH.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "${GODOT_BIN}" >/dev/null 2>&1; then
  echo "[run_static_checks] Unable to find Godot executable '${GODOT_BIN}'." >&2
  echo "Set GODOT_BIN to the path of your Godot 4.5 binary." >&2
  exit 1
fi

set -x
"${GODOT_BIN}" \
  --headless \
  --path "${PROJECT_ROOT}" \
  --check-only
