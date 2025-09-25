class_name _PlayerController2D
extends CharacterBody2D

## Flexible 2D player controller driven by MovementConfig and a reusable StateMachine.

signal player_spawned(position: Vector2)
signal player_jumped()
signal player_landed()
signal state_changed(previous: StringName, current: StringName)
signal state_event(event: StringName, data: Variant)
signal interaction_available_changed(available: bool)
signal ability_registered(ability_id: StringName, ability: Node)
signal ability_unregistered(ability_id: StringName)
# Health signals removed - use EventBus topics instead:
# EventTopics.PLAYER_DAMAGED, EventTopics.PLAYER_HEALED, EventTopics.PLAYER_DIED

const EventTopics = preload("res://EventBus/EventTopics.gd")
const MovementConfigScript = preload("res://PlayerController/MovementConfig.gd")
const StateMachineScript = preload("res://systems/fsm/StateMachine.gd")
const IdleStateScript = preload("res://PlayerController/states/PlayerStateIdle.gd")
const MoveStateScript = preload("res://PlayerController/states/PlayerStateMove.gd")
const JumpStateScript = preload("res://PlayerController/states/PlayerStateJump.gd")
const FallStateScript = preload("res://PlayerController/states/PlayerStateFall.gd")
const InteractionDetectorScript = preload("res://PlayerController/InteractionDetector.gd")
const AbilityScript = preload("res://PlayerController/Ability.gd")
const HealthComponentScript = preload("res://Combat/HealthComponent.gd")
const DamageInfoScript = preload("res://Combat/DamageInfo.gd")

const STATE_IDLE := StringName("idle")
const STATE_MOVE := StringName("move")
const STATE_JUMP := StringName("jump")
const STATE_FALL := StringName("fall")

@export var movement_config: MovementConfigScript
@export var manual_input_enabled: bool = false
@export var manual_input_vector: Vector2 = Vector2.ZERO
@export var state_machine_path: NodePath
@export var enable_interaction_detector: bool = true
@export var interaction_detector_range: float = 32.0

var _velocity: Vector2 = Vector2.ZERO
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_on_floor: bool = false
var _state_machine: StateMachine
var _input_service_connected: bool = false
var _axis_values: Dictionary[StringName, float] = {}
var _interaction_detector: InteractionDetectorScript = null
var _abilities: Dictionary[StringName, Node] = {}
var _health_component: HealthComponentScript = null

func _ready() -> void:
    if movement_config == null:
        movement_config = MovementConfigScript.new()
    _resolve_state_machine()
    _setup_health_component()
    _setup_interaction_detector()
    _connect_input_service()
    _connect_eventbus_input()
    _connect_eventbus_health()
    _was_on_floor = is_on_floor()

func _process(delta: float) -> void:
    if _state_machine:
        _state_machine.update_state(delta)

    # Update active abilities
    for ability in _abilities.values():
        ability.update_state(delta)

func _physics_process(delta: float) -> void:
    if movement_config == null:
        return
    if _state_machine:
        _refresh_state_context()
        _state_machine.physics_update_state(delta)
    velocity = _velocity
    move_and_slide()
    _update_after_physics(delta)

func spawn(spawn_position: Vector2) -> void:
    """Teleport the player to a spawn position and emit analytics hooks."""
    global_position = spawn_position
    _velocity = Vector2.ZERO
    player_spawned.emit(spawn_position)
    _emit_player_event(EventTopics.PLAYER_SPAWNED, {
        StringName("position"): spawn_position
    } as Dictionary[StringName, Variant])

func set_manual_input(vector: Vector2) -> void:
    manual_input_vector = vector

func enable_manual_input(enabled: bool) -> void:
    manual_input_enabled = enabled

func set_config(config: MovementConfigScript) -> void:
    movement_config = config
    _refresh_state_context()

func get_controller_velocity() -> Vector2:
    return _velocity

func register_additional_state(state_id: StringName, resource: Resource) -> void:
    """Register a custom ability state with the underlying StateMachine."""
    if _state_machine:
        _state_machine.register_state(state_id, resource)

func transition_to_state(state_id: StringName, payload: Dictionary[StringName, Variant] = {}) -> Error:
    """Request a transition to a specific state, typically used by abilities."""
    if _state_machine == null:
        return ERR_DOES_NOT_EXIST
    return _state_machine.transition_to(state_id, payload)

func get_current_state() -> StringName:
    return _state_machine.get_current_state() if _state_machine else StringName()

func enable_gameplay_input(enabled: bool) -> void:
    """Enable or disable gameplay input context."""
    if Engine.has_singleton("InputService"):
        var input_service := Engine.get_singleton("InputService") as Object
        if input_service and input_service.has_method("enable_context"):
            input_service.call("enable_context", "gameplay", enabled)

func is_platformer_mode() -> bool:
    return movement_config != null and movement_config.movement_mode == 0  # MovementMode.PLATFORMER

func is_top_down_mode() -> bool:
    return movement_config != null and movement_config.movement_mode == 1  # MovementMode.TOP_DOWN

func get_movement_input() -> Vector2:
    var input_vector := manual_input_vector if manual_input_enabled else _sample_input()
    if input_vector.length() > 1.0:
        input_vector = input_vector.normalized()
    return _apply_deadzone(input_vector)

func move_platformer_horizontal(input_dir: float, delta: float, is_airborne: bool) -> void:
    var target_speed: float = input_dir * movement_config.max_speed
    var accel: float = movement_config.air_acceleration if is_airborne else movement_config.acceleration
    var decel: float = movement_config.air_deceleration if is_airborne else movement_config.deceleration
    if abs(target_speed) > abs(_velocity.x):
        _velocity.x = move_toward(_velocity.x, target_speed, accel * delta)
    else:
        _velocity.x = move_toward(_velocity.x, target_speed, decel * delta)
    if not is_airborne and is_equal_approx(input_dir, 0.0) and movement_config.friction > 0.0:
        _velocity.x = move_toward(_velocity.x, 0.0, movement_config.friction * delta)

func move_top_down(input_vector: Vector2, delta: float) -> void:
    var target_velocity := input_vector * movement_config.max_speed
    _velocity.x = _move_component(_velocity.x, target_velocity.x, delta, movement_config.acceleration, movement_config.deceleration)
    _velocity.y = _move_component(_velocity.y, target_velocity.y, delta, movement_config.acceleration, movement_config.deceleration)
    if input_vector.length_squared() == 0.0 and movement_config.friction > 0.0:
        _velocity.x = move_toward(_velocity.x, 0.0, movement_config.friction * delta)
        _velocity.y = move_toward(_velocity.y, 0.0, movement_config.friction * delta)

func apply_gravity(delta: float) -> void:
    if not is_platformer_mode():
        return
    _velocity.y += movement_config.gravity * delta
    if _velocity.y > movement_config.max_fall_speed:
        _velocity.y = movement_config.max_fall_speed

func start_jump() -> void:
    _velocity.y = movement_config.jump_velocity
    player_jumped.emit()
    _emit_player_event(EventTopics.PLAYER_JUMPED, {} as Dictionary[StringName, Variant])
    _jump_buffer_timer = 0.0
    _coyote_timer = 0.0

func consume_jump_request() -> bool:
    if not is_platformer_mode() or not movement_config.allow_jump:
        return false
    if _jump_buffer_timer <= 0.0:
        return false
    if not is_on_floor() and _coyote_timer <= 0.0:
        return false
    _jump_buffer_timer = 0.0
    _coyote_timer = 0.0
    return true

func refresh_coyote_timer() -> void:
    if is_platformer_mode():
        _coyote_timer = movement_config.coyote_time

func set_motion_velocity(velocity_value: Vector2) -> void:
    _velocity = velocity_value

func get_motion_velocity() -> Vector2:
    return _velocity

func _exit_tree() -> void:
    _disconnect_input_service()
    _disconnect_eventbus_input()
    _disconnect_eventbus_health()

func _setup_health_component() -> void:
    _health_component = HealthComponentScript.new()
    _health_component.max_health = 100.0  # Could be configurable
    _health_component.invulnerability_duration = 0.5
    _health_component.auto_register_with_save_service = false  # We'll handle save registration
    add_child(_health_component)

    # HealthComponent already publishes to EventBus - no need for signal forwarding

func _setup_interaction_detector() -> void:
    if not enable_interaction_detector or Engine.is_editor_hint():
        return

    _interaction_detector = InteractionDetectorScript.new()
    _interaction_detector.interaction_range = interaction_detector_range
    _interaction_detector.interaction_available_changed.connect(_on_interaction_available_changed)
    add_child(_interaction_detector)

func is_interaction_available() -> bool:
    return _interaction_detector != null and _interaction_detector.is_interaction_available()

func get_current_interactable() -> Node:
    return _interaction_detector.get_current_interactable() if _interaction_detector else null

func interact() -> void:
    if _interaction_detector:
        _interaction_detector.interact()

func _on_interaction_available_changed(available: bool) -> void:
    interaction_available_changed.emit(available)

# Health signal forwarding removed - use EventBus topics instead:
# Subscribe to EventTopics.PLAYER_DAMAGED, EventTopics.PLAYER_HEALED, EventTopics.PLAYER_DIED

func register_ability(ability_id: StringName, ability: Node) -> void:
    if _abilities.has(ability_id):
        push_warning("Ability '%s' is already registered" % ability_id)
        return

    ability.setup(self, ability_id)
    _abilities[ability_id] = ability
    ability_registered.emit(ability_id, ability)

func unregister_ability(ability_id: StringName) -> void:
    if not _abilities.has(ability_id):
        push_warning("Ability '%s' is not registered" % ability_id)
        return

    var ability := _abilities[ability_id]
    _abilities.erase(ability_id)
    ability.deactivate()
    ability_unregistered.emit(ability_id)

func get_ability(ability_id: StringName) -> Node:
    return _abilities.get(ability_id, null)

func activate_ability(ability_id: StringName) -> void:
    var ability := get_ability(ability_id)
    if ability:
        ability.activate()

func deactivate_ability(ability_id: StringName) -> void:
    var ability := get_ability(ability_id)
    if ability:
        ability.deactivate()

# Combat/Damage System - Delegates to HealthComponent
func take_damage(amount: float, source: Node = null, damage_type: String = "physical") -> void:
    """Apply damage to the player using DamageInfo."""
    if not _health_component:
        push_error("HealthComponent not available")
        return

    var damage_info := DamageInfoScript.create_damage(amount, _get_damage_type_enum(damage_type), source)
    _health_component.take_damage(damage_info)

func heal(amount: float, source: Node = null) -> void:
    """Heal the player using DamageInfo."""
    if not _health_component:
        push_error("HealthComponent not available")
        return

    var healing_info := DamageInfoScript.create_healing(amount, source)
    _health_component.heal(healing_info)

func die(source: Node = null) -> void:
    """Kill the player immediately."""
    if _health_component:
        _health_component.kill(source)

func set_max_health(new_max: float) -> void:
    """Set the maximum health value."""
    if _health_component:
        _health_component.max_health = new_max

func get_health() -> float:
    """Get current health value."""
    return _health_component.get_health() if _health_component else 0.0

func get_max_health() -> float:
    """Get maximum health value."""
    return _health_component.get_max_health() if _health_component else 0.0

func get_health_percentage() -> float:
    """Get health as a percentage (0.0 to 1.0)."""
    return _health_component.get_health_percentage() if _health_component else 0.0

func is_alive() -> bool:
    """Check if the player is alive."""
    return _health_component.is_alive() if _health_component else false

func is_full_health() -> bool:
    """Check if the player has full health."""
    return _health_component.is_full_health() if _health_component else false

func set_invulnerable(duration: float) -> void:
    """Make the player invulnerable for a specified duration."""
    if _health_component:
        _health_component.set_invulnerable(true, duration)

func is_invulnerable() -> bool:
    """Check if the player is currently invulnerable."""
    return _health_component.is_invulnerable() if _health_component else false

func _get_damage_type_enum(damage_type: String) -> int:
    """Convert string damage type to enum value."""
    match damage_type.to_lower():
        "physical": return DamageInfoScript.DamageType.PHYSICAL
        "magical", "magic": return DamageInfoScript.DamageType.MAGICAL
        "fire": return DamageInfoScript.DamageType.FIRE
        "ice": return DamageInfoScript.DamageType.ICE
        "lightning": return DamageInfoScript.DamageType.LIGHTNING
        "poison": return DamageInfoScript.DamageType.POISON
        "true": return DamageInfoScript.DamageType.TRUE
        "healing": return DamageInfoScript.DamageType.HEALING
        _: return DamageInfoScript.DamageType.PHYSICAL

# Save/Load System - ISaveable Implementation
func save_data() -> Dictionary:
    """Save player state for persistence."""
    var health_data := {}
    if _health_component:
        health_data = _health_component.save_data()

    return {
        "position": {
            "x": global_position.x,
            "y": global_position.y
        },
        "velocity": {
            "x": _velocity.x,
            "y": _velocity.y
        },
        "current_state": _state_machine.get_current_state() if _state_machine else StringName(),
        "abilities": _get_active_abilities_data(),
        "health_data": health_data  # Delegate health saving to HealthComponent
    }

func load_data(data: Dictionary) -> bool:
    """Load player state from saved data."""
    if not data.has("position"):
        return false

    # Load position
    var pos_data = data.position
    global_position = Vector2(
        pos_data.get("x", 0.0),
        pos_data.get("y", 0.0)
    )

    # Load velocity
    if data.has("velocity"):
        var vel_data = data.velocity
        _velocity = Vector2(
            vel_data.get("x", 0.0),
            vel_data.get("y", 0.0)
        )

    # Load state machine state
    var saved_state = data.get("current_state", "")
    if _state_machine and saved_state != "":
        _state_machine.transition_to(StringName(saved_state), {})

    # Load abilities
    var abilities_data = data.get("abilities", {})
    _load_abilities_data(abilities_data)

    # Load health data (delegate to HealthComponent)
    var health_data = data.get("health_data", {})
    if _health_component and not health_data.is_empty():
        _health_component.load_data(health_data)

    return true

func get_save_id() -> String:
    """Unique identifier for this saveable object."""
    return "player_controller"

func get_save_priority() -> int:
    """Priority for save/load order. Lower numbers save first."""
    return 10  # High priority - save player state early

func _get_active_abilities_data() -> Dictionary:
    """Get data for active abilities."""
    var data := {}
    for ability_id in _abilities:
        var ability = _abilities[ability_id]
        if ability.is_active():
            data[ability_id] = {
                "active": true,
                "custom_data": ability.save_data() if ability.has_method("save_data") else {}
            }
    return data

func _load_abilities_data(abilities_data: Dictionary) -> void:
    """Load abilities from saved data."""
    for ability_id in abilities_data:
        var ability_data = abilities_data[ability_id]
        var ability = get_ability(StringName(ability_id))
        if ability:
            var was_active = ability_data.get("active", false)
            if was_active:
                ability.activate()
            else:
                ability.deactivate()

            # Load custom ability data
            var custom_data = ability_data.get("custom_data", {})
            if ability.has_method("load_data"):
                ability.load_data(custom_data)

func _resolve_state_machine() -> void:
    if state_machine_path.is_empty():
        _ensure_state_machine_child()
    var node := get_node_or_null(state_machine_path)
    if node is StateMachine:
        _state_machine = node
        _register_builtin_states()
        _refresh_state_context()
        if not _state_machine.state_changed.is_connected(_on_state_changed):
            _state_machine.state_changed.connect(_on_state_changed)
        if not _state_machine.state_event.is_connected(_on_state_event):
            _state_machine.state_event.connect(_on_state_event)
        if _state_machine.get_current_state() == StringName():
            _state_machine.transition_to(STATE_IDLE)

func _ensure_state_machine_child() -> void:
    if state_machine_path.is_empty():
        var existing := find_child("StateMachine", true, false)
        if existing is StateMachine:
            state_machine_path = existing.get_path()
            return
        var machine := StateMachineScript.new() as StateMachine
        machine.name = "StateMachine"
        add_child(machine)
        await machine.ready
        state_machine_path = machine.get_path()

func _register_builtin_states() -> void:
    if _state_machine == null:
        return
    if not _state_machine.has_state(STATE_IDLE):
        _state_machine.register_state(STATE_IDLE, IdleStateScript)
    if not _state_machine.has_state(STATE_MOVE):
        _state_machine.register_state(STATE_MOVE, MoveStateScript)
    if is_platformer_mode():
        if not _state_machine.has_state(STATE_JUMP):
            _state_machine.register_state(STATE_JUMP, JumpStateScript)
        if not _state_machine.has_state(STATE_FALL):
            _state_machine.register_state(STATE_FALL, FallStateScript)
    else:
        _state_machine.unregister_state(STATE_JUMP)
        _state_machine.unregister_state(STATE_FALL)
    var current := _state_machine.get_current_state()
    if current == StringName() or not _state_machine.has_state(current):
        _state_machine.transition_to(STATE_IDLE)

func _refresh_state_context() -> void:
    if _state_machine == null:
        return
    var context := {
        StringName("movement_config"): movement_config,
        StringName("controller"): self
    } as Dictionary[StringName, Variant]
    _state_machine.set_context(context)
    _register_builtin_states()

func _sample_input() -> Vector2:
    if movement_config == null:
        return Vector2.ZERO
    
    # Use EventBus-based input from InputService (no more manual polling)
    if _input_service_connected and Engine.has_singleton("InputService"):
        var x: float = clamp(_axis_values.get(StringName("move_x"), 0.0), -1.0, 1.0)
        var y: float = clamp(_axis_values.get(StringName("move_y"), 0.0), -1.0, 1.0)
        if not movement_config.allow_vertical_input:
            y = 0.0
        return Vector2(x, y)
    
    # Fallback: return zero if InputService is not available
    # This ensures the system degrades gracefully
    push_warning("PlayerController: InputService not available, input will be zero")
    return Vector2.ZERO

func _apply_deadzone(input_vector: Vector2) -> Vector2:
    var deadzone: float = movement_config.movement_input_deadzone if movement_config else 0.0
    if deadzone <= 0.0:
        return input_vector
    return Vector2(
        0.0 if abs(input_vector.x) < deadzone else input_vector.x,
        0.0 if abs(input_vector.y) < deadzone else input_vector.y
    )

func _move_component(current: float, target: float, delta: float, accel: float, decel: float) -> float:
    if abs(target) > abs(current):
        return move_toward(current, target, accel * delta)
    return move_toward(current, target, decel * delta)

func _update_after_physics(delta: float) -> void:
    if not is_platformer_mode():
        _jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
        _was_on_floor = true
        return
    var on_floor := is_on_floor()
    if on_floor and not _was_on_floor:
        player_landed.emit()
        _emit_player_event(EventTopics.PLAYER_LANDED, {} as Dictionary[StringName, Variant])
    if on_floor:
        _coyote_timer = movement_config.coyote_time
    else:
        _coyote_timer = max(_coyote_timer - delta, 0.0)
    _jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
    _was_on_floor = on_floor

func _register_with_save_service() -> void:
    """Register this player controller with the SaveService."""
    if Engine.has_singleton("SaveService"):
        var save_service := Engine.get_singleton("SaveService") as Object
        if save_service and save_service.has_method("register_saveable"):
            save_service.call("register_saveable", self)

func _connect_input_service() -> void:
    if Engine.is_editor_hint() or _input_service_connected:
        return
    if Engine.has_singleton("InputService"):
        var input_service := Engine.get_singleton("InputService") as Object
        if input_service and input_service.has_signal("action_event"):
            input_service.action_event.connect(_on_action_event)
            _input_service_connected = true
        if input_service and input_service.has_signal("axis_event"):
            input_service.axis_event.connect(_on_axis_event)
            _input_service_connected = true
        if input_service and input_service.has_method("enable_context"):
            input_service.call("enable_context", "gameplay", true)

func _disconnect_input_service() -> void:
    if not _input_service_connected or Engine.is_editor_hint():
        return
    if Engine.has_singleton("InputService"):
        var input_service := Engine.get_singleton("InputService") as Object
        if input_service and input_service.has_signal("action_event"):
            input_service.action_event.disconnect(_on_action_event)
        if input_service and input_service.has_signal("axis_event"):
            input_service.axis_event.disconnect(_on_axis_event)
    _input_service_connected = false

func _connect_eventbus_input() -> void:
    """Connect to EventBus input events as primary input source."""
    if Engine.is_editor_hint():
        return
    if Engine.has_singleton("EventBus"):
        var event_bus := Engine.get_singleton("EventBus") as Object
        if event_bus and event_bus.has_method("sub"):
            # Subscribe to input events from EventBus
            event_bus.call("sub", EventTopics.INPUT_ACTION, _on_eventbus_action)
            event_bus.call("sub", EventTopics.INPUT_AXIS, _on_eventbus_axis)

func _disconnect_eventbus_input() -> void:
    """Disconnect from EventBus input events."""
    if Engine.is_editor_hint():
        return
    if Engine.has_singleton("EventBus"):
        var event_bus := Engine.get_singleton("EventBus") as Object
        if event_bus and event_bus.has_method("unsub"):
            event_bus.call("unsub", EventTopics.INPUT_ACTION, _on_eventbus_action)
            event_bus.call("unsub", EventTopics.INPUT_AXIS, _on_eventbus_axis)

func _on_eventbus_action(payload: Dictionary) -> void:
    """Handle input action events from EventBus."""
    var action: StringName = payload.get("action", StringName(""))
    var edge: String = payload.get("edge", "")
    var device: int = payload.get("device", 0)
    
    # Handle jump input
    if action == movement_config.jump_action and edge == "pressed":
        _record_jump_buffer()
    
    # Handle interact input
    if action == movement_config.interact_action and edge == "pressed":
        interact()
    
    # Forward to abilities
    for ability in _abilities.values():
        ability.handle_input_action(action, edge, device, null)

func _on_eventbus_axis(payload: Dictionary) -> void:
    """Handle input axis events from EventBus."""
    var axis: StringName = payload.get("axis", StringName(""))
    var value: float = payload.get("value", 0.0)
    var device: int = payload.get("device", 0)
    
    # Store axis value for movement input
    _axis_values[axis] = clamp(value, -1.0, 1.0)
    
    # Forward to abilities
    for ability in _abilities.values():
        ability.handle_input_axis(axis, value, device)

func _on_action_event(action: StringName, edge: String, device: int, event: InputEvent) -> void:
    if action == movement_config.jump_action and edge == "pressed":
        _record_jump_buffer()

    # Handle interact input
    if action == movement_config.interact_action and edge == "pressed":
        interact()

    # Forward to abilities
    for ability in _abilities.values():
        ability.handle_input_action(action, edge, device, event)

func _on_axis_event(axis: StringName, value: float, device: int) -> void:
    if not _input_service_connected:
        return
    _axis_values[axis] = clamp(value, -1.0, 1.0)

    # Forward to abilities
    for ability in _abilities.values():
        ability.handle_input_axis(axis, value, device)

func _record_jump_buffer() -> void:
    if not is_platformer_mode() or not movement_config.allow_jump:
        return
    _jump_buffer_timer = movement_config.jump_buffer_time

func _on_state_changed(previous: StringName, current: StringName) -> void:
    state_changed.emit(previous, current)
    _emit_player_event(EventTopics.PLAYER_STATE_CHANGED, {
        StringName("previous"): previous,
        StringName("current"): current
    } as Dictionary[StringName, Variant])

    # Notify abilities of state change
    for ability in _abilities.values():
        ability.handle_state_event(StringName("state_changed"), {
            StringName("previous"): previous,
            StringName("current"): current
        })

func _on_state_event(event: StringName, data: Variant) -> void:
    state_event.emit(event, data)

    # Forward to abilities
    for ability in _abilities.values():
        ability.handle_state_event(event, data)

func _emit_player_event(topic: StringName, payload: Dictionary[StringName, Variant]) -> void:
    if Engine.has_singleton("EventBus"):
        payload[StringName("timestamp_ms")] = Time.get_ticks_msec()
        Engine.get_singleton("EventBus").call("pub", topic, payload)

func _connect_eventbus_health() -> void:
    """Connect to EventBus health events for player-specific handling."""
    if Engine.is_editor_hint():
        return
    if Engine.has_singleton("EventBus"):
        var event_bus := Engine.get_singleton("EventBus") as Object
        if event_bus and event_bus.has_method("sub"):
            # Subscribe to combat events for this player
            event_bus.call("sub", EventTopics.COMBAT_HIT, _on_eventbus_damage)
            event_bus.call("sub", EventTopics.COMBAT_HEAL, _on_eventbus_heal)
            event_bus.call("sub", EventTopics.COMBAT_ENTITY_DEATH, _on_eventbus_death)

func _disconnect_eventbus_health() -> void:
    """Disconnect from EventBus health events."""
    if Engine.is_editor_hint():
        return
    if Engine.has_singleton("EventBus"):
        var event_bus := Engine.get_singleton("EventBus") as Object
        if event_bus and event_bus.has_method("unsub"):
            event_bus.call("unsub", EventTopics.COMBAT_HIT, _on_eventbus_damage)
            event_bus.call("unsub", EventTopics.COMBAT_HEAL, _on_eventbus_heal)
            event_bus.call("unsub", EventTopics.COMBAT_ENTITY_DEATH, _on_eventbus_death)

func _on_eventbus_damage(payload: Dictionary) -> void:
    """Handle damage events from EventBus for this player."""
    var target = payload.get("target", null)
    if target != self:
        return  # Not for this player
    
    var amount = payload.get("amount", 0.0)
    var source = payload.get("source", null)
    var damage_type = payload.get("type", "unknown")
    
    # Emit player-specific event for UI/systems that need it
    _emit_player_event(EventTopics.PLAYER_DAMAGED, {
        StringName("amount"): amount,
        StringName("source"): source,
        StringName("hp_after"): _health_component.get_health() if _health_component else 0.0,
        StringName("damage_type"): damage_type
    } as Dictionary[StringName, Variant])

func _on_eventbus_heal(payload: Dictionary) -> void:
    """Handle heal events from EventBus for this player."""
    var target = payload.get("target", null)
    if target != self:
        return  # Not for this player
    
    var amount = payload.get("amount", 0.0)
    var source = payload.get("source", null)
    
    # Emit player-specific event for UI/systems that need it
    _emit_player_event(EventTopics.PLAYER_HEALED, {
        StringName("amount"): amount,
        StringName("source"): source,
        StringName("hp_after"): _health_component.get_health() if _health_component else 0.0
    } as Dictionary[StringName, Variant])

func _on_eventbus_death(payload: Dictionary) -> void:
    """Handle death events from EventBus for this player."""
    var target = payload.get("target", null)
    if target != self:
        return  # Not for this player
    
    var source = payload.get("source", null)
    
    # Emit player-specific event for UI/systems that need it
    _emit_player_event(EventTopics.PLAYER_DIED, {
        StringName("source"): source
    } as Dictionary[StringName, Variant])
