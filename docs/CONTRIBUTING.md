# Contributing

This repository follows the automation safeguards laid out in `AGENTS.md` and the system design in `SOLUTION-DESIGN-DOC.md`. Review both documents before making any changes.

## Workflow Expectations

- Complete work milestone-by-milestone as documented in `docs/MILESTONES.md`.
- Each TODO bullet corresponds to **one** implementation commit using [Conventional Commits](https://www.conventionalcommits.org/).
- After finishing every milestone, add a **test-only** commit containing the GUT coverage for that milestone.
- Keep public APIs at the top of scripts, strongly type parameters/returns, and include docstrings for public methods.

## Conventional Commit Format

```
<type>(optional-scope): <short description>
```

Common types:

- `feat`: user-facing or API additions.
- `fix`: bug fixes or regressions.
- `chore`: tooling, CI, or repo maintenance.
- `docs`: documentation updates.
- `refactor`: internal changes without behaviour differences.
- `test`: additional automated tests.

Examples:

- `feat(flow): add push_scene API`
- `test(event-bus): cover duplicated subscribers`

## Local Verification Checklist

Before committing:

- Run `godot --headless --check-only` to ensure scripts pass type checks.
- Format any GDScript changes using `gdformat` (if available) or your editor formatter.
- Execute GUT suites via `godot --headless --script res://addons/gut/gut_cmdln.gd -gdir=res://<tests>`.

Set `GODOT_BIN` when a non-default binary path is required. Keep `GUT_SORT_TESTS=1` for deterministic ordering if needed.

## Saving & Autoload Constraints

- Never edit `project.godot` directly; use the provided setup scripts for autoloads/input actions.
- Scenes should rely on exported `NodePath` references (see `AGENTS.md`).
- Save logic routes through `SaveService`; other systems expose snapshot hooks only.

## Pull Requests

- Include reasoning for design decisions when deviating from defaults.
- Reference any new EventBus topics or analytics payloads in module documentation.
- Keep commits focused; avoid mixing unrelated changes to simplify reviews.

## Optional Git Hooks

A ready-to-use commit message hook lives under `.githooks/commit-msg`. Enable it locally:

```bash
git config core.hooksPath .githooks
```

This keeps enforcement opt-in and repository-scoped without touching global Git settings.
