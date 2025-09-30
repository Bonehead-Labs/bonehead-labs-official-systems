## Ability System and AbilityManager Specification (Agent-Focused)

### Objective

Create a modular ability system centered on an `AbilityManager` node that owns ability lifecycle, input routing, per-frame orchestration, and deterministic motion arbitration. The controller remains focused on locomotion and state; abilities remain standalone and composable. Backwards compatibility is not required.

### Constraints and Integration

- Engine: Godot 4.5+; follow project static typing and best practices.
- Player root: `CharacterBody2D` with an FSM (`StateMachine`) and services integration.
- Services: `InputService`, `EventBus`, `SaveService`, `AudioService` remain decoupled and accessible.
- Input source-of-truth: single wiring in controller (from `InputService`/`EventBus`). Controller forwards input to `AbilityManager`.

### Components

- AbilityManager (Node)
  - Child of player. Single instance per player.
  - Responsibilities:
    - Registry: register/unregister/activate/deactivate abilities by `StringName` id.
    - Input routing: receive action/axis events once; dispatch to active abilities.
    - Orchestration: call ability update and physics-update in deterministic order.
    - Arbitration: determine motion override winner (priority-based); gate FSM logic/physics updates when required.
    - Telemetry: emit lifecycle signals and publish debug/analytics via `EventBus`.
    - Persistence: save unlocked/active abilities and optional runtime state via `SaveService`.

- PlayerAbility (RefCounted)
  - Base contract for standalone abilities.
  - Must expose: lifecycle, input hooks, update hooks, optional capabilities for arbitration/gating.
  - Must not directly depend on other abilities; communicate via controller/manager/events.

### Required Behavior

- Registration
  - Abilities are registered with unique `StringName` ids.
  - Manager injects controller reference during setup.
  - Activation may be automatic or explicit per ability or configuration.

- Input
  - Controller forwards all input actions/axes to manager.
  - Manager forwards to active abilities; abilities choose whether to consume/ignore.

- Update Order
  - Manager invokes ability updates each frame in logic and physics phases.
  - Determinism: ordering must be stable (registration order or explicit priority list). No randomization.

- Motion Arbitration
  - Abilities may declare that they override motion for the current frame.
  - Manager selects a single winner by highest priority; ties resolved by registration order.
  - While an ability owns motion, manager may block FSM physics updates to avoid velocity contention.
  - Controller applies the resolved motion before `move_and_slide()`.

- State Gating
  - Abilities can request gating of FSM logic or physics phases by kind (e.g., `"logic"`, `"physics"`).

- Telemetry
  - Manager emits `ability_started`, `ability_ended`, `ability_failed` events.
  - Structured debug logs should be publishable to `EventBus` under a clear topic for external tools/overlays.

- Persistence (optional)
  - Store unlocked/active ability ids, tunables, and optional cooldown remainders using `SaveService` profiles.

### PlayerAbility Contract (New System)

- Lifecycle
  - `setup(controller: Node, id: StringName)` — called when registered; provides controller reference and id.
  - `activate()` — ability becomes active and starts receiving hooks.
  - `deactivate()` — ability stops receiving hooks.

- Input Hooks (invoked only when active)
  - `handle_input_action(action: StringName, edge: String, device: int, event: InputEvent)`
  - `handle_input_axis(axis: StringName, value: float, device: int)`

- Update Hooks (invoked only when active)
  - `on_update(delta: float)` — frame-time behavior.
  - `on_physics_update(delta: float)` — physics-time behavior when needed.

- Arbitration Capabilities (optional)
  - `is_overriding_motion() -> bool` — true when the ability owns motion this frame.
  - `motion_priority() -> float` — higher value wins arbitration.
  - `motion_velocity() -> Vector2` — velocity to apply when owning motion.
  - `blocks_state_kind(kind: StringName) -> bool` — allows gating of `"logic"` and/or `"physics"` FSM updates.

- Utilities (provided by base ability)
  - Access to controller and ability id.
  - Helpers for emitting lifecycle/analytics events through `EventBus`.

### Controller Responsibilities (with AbilityManager)

- Resolve `AbilityManager` child and initialize it with controller context.
- Forward all action/axis events to manager (single source-of-truth for input).
- Each frame:
  - Call manager update and physics-update.
  - Query manager for FSM gating and skip FSM updates when required.
  - If manager reports motion override, apply manager-provided velocity before `move_and_slide()`.

### Determinism and Priorities

- Registration order is stable and acts as a deterministic tie-break after numeric priority.
- Abilities may expose constant or time-varying priorities; manager must evaluate per-frame.
- Only one ability may own the motion channel per frame.

### Debugging and Observability Requirements

- Global verbose flag at manager-level to enable/disable per-frame traces.
- Emit lifecycle signals with minimal payload (id, timestamps, optional metadata) for external subscribers.
- Publish structured debug logs to `EventBus` for use by in-game debug UIs and headless logs.

### Persistence Requirements (Optional)

- Profile-scoped persistence of ability unlocks and activation state via `SaveService`.
- Optional: per-ability runtime state (e.g., cooldown remainders) if required by design.

### Migration Instructions (Authoring Workflow for Agents)

1. Add `AbilityManager` node under the player scene and initialize it with controller context.
2. Move ability registration/activation from the controller into the manager.
3. Wire controller input to manager; remove direct per-ability calls from controller.
4. Update controller loops to consult manager for FSM gating and motion override.
5. Update abilities to implement the new hooks/capability methods as needed (motion owners must report priority and velocity).
6. (If required) integrate persistence of unlocks/activation via `SaveService`.


