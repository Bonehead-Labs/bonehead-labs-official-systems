# Continuous Integration Guide

This repository ships headless-friendly scripts for static checks and unit tests. They intentionally avoid modifying `project.godot` and respect the safeguards in `AGENTS.md`.

## Godot Binary

All scripts expect a Godot **4.5** executable. Override the binary path with the `GODOT_BIN` environment variable when the command is not simply `godot` on your `PATH`.

```bash
export GODOT_BIN="$HOME/Applications/Godot_v4.5-stable_linux.x86_64"
```

## Static Analysis & Formatting

Run static checks, formatting validation, and GUT tests using your preferred tooling (e.g., agentic automation or manual commands).

- Type checks: `godot --headless --check-only`
- Formatting: `gdformat` or editor-integrated formatters
- Tests: `godot --headless --script res://addons/gut/gut_cmdln.gd -gdir=res://<tests>`
If any command fails, resolve issues before committing to preserve a clean history and keep CI green.
