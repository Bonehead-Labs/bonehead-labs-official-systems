#!/usr/bin/env bash
set -euo pipefail

# Validates GDScript formatting using gdformat when available.
# Requires gdformat from gdtoolkit. Skip silently if unavailable.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GD_FORMAT_BIN="${GD_FORMAT_BIN:-gdformat}"

if ! command -v "${GD_FORMAT_BIN}" >/dev/null 2>&1; then
  echo "[run_format_check] gdformat not found; skipping format validation." >&2
  exit 0
fi

# gdformat expects filesystem paths; run in repository root.
cd "${PROJECT_ROOT}"

# Use git to locate tracked GDScript files for consistent formatting checks.
mapfile -t GDSCRIPTS < <(git ls-files '*.gd')
if [ "${#GDSCRIPTS[@]}" -eq 0 ]; then
  echo "[run_format_check] No GDScript files to check." >&2
  exit 0
fi

set -x
"${GD_FORMAT_BIN}" --check "${GDSCRIPTS[@]}"
