# Continuous Integration Guide

This repository ships headless-friendly scripts for static checks and unit tests. They intentionally avoid modifying `project.godot` and respect the safeguards in `AGENTS.md`.

## Godot Binary

All scripts expect a Godot **4.5** executable. Override the binary path with the `GODOT_BIN` environment variable when the command is not simply `godot` on your `PATH`.

```bash
export GODOT_BIN="$HOME/Applications/Godot_v4.5-stable_linux.x86_64"
```

## Static Analysis & Formatting

Run static checks and optional formatting validation:

```bash
scripts/ci/run_static_checks.sh
scripts/ci/run_format_check.sh   # requires `gdformat`
```

`run_static_checks.sh` wraps `godot --headless --check-only` to ensure all scripts type-check. The formatter script short-circuits when `gdformat` is unavailable, keeping CI pipelines portable.

## Headless GUT Tests

Execute all discovery-based GUT suites (any folder named `UnitTests`):

```bash
scripts/ci/run_gut_tests.sh
```

The runner:
- scans for `UnitTests` directories and converts them to `res://` paths,
- sets `GUT_SORT_TESTS=1` for deterministic ordering,
- runs the standard GUT CLI (`res://addons/gut/gut_cmdln.gd`) with `-gexit` and `--headless`.

## Suggested CI Workflow

1. Install Godot 4.5 and (optionally) `gdformat`.
2. Cache the `addons/` directory to speed up dependency fetches (contains GUT already).
3. Run the scripts above in order:
   - `scripts/ci/run_format_check.sh`
   - `scripts/ci/run_static_checks.sh`
   - `scripts/ci/run_gut_tests.sh`

## Local Verification

Before every Conventional Commit:

```bash
scripts/ci/run_format_check.sh
scripts/ci/run_static_checks.sh
scripts/ci/run_gut_tests.sh
```

If any command fails, resolve issues before committing to preserve a clean history and keep CI green.
