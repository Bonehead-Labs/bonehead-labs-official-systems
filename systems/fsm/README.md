# Scriptable Finite State Machine

`systems/fsm` provides reusable state-machine scaffolding for gameplay systems (player, enemies, UI).

## Components

- `StateMachine.gd`: node you add to an owner (e.g., Player, Enemy) to manage states
- `State.gd`: base class for concrete state scripts, exposes hooks (`enter`, `exit`, `update`, `physics_update`, `handle_event`)

## Usage

1. Create state scenes extending `FSMState`
2. Register them with `state_scripts` or via `register_state`
3. Call `transition_to(new_state)` to change behavior
4. Provide shared context via `set_context`

Signals:
- `state_entered`, `state_exited`, `state_changed`
- `state_event` for custom events emitted by states

Tests under `systems/fsm/UnitTests` cover transition flow and event propagation.

## Integration Guide

- **Player Controller**: attach a `StateMachine` as a child of the player node, set `state_scripts` to player-specific states (idle, move, jump). Pass configuration resources via `set_context` so states stay data-driven.
- **Enemy AI**: instantiate a `StateMachine` inside enemy scenes. Register behaviour states (patrol, chase, attack) at runtime to keep prefabs lightweight.
- **Debug Tools**: listen to `state_changed`/`state_event` signals to drive overlays or analytics without coupling to specific implementations.
