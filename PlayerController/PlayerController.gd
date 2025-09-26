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
var _autoload_cache: Dictionary[StringName, Node] = {}
var _warned_missing_input_service: bool = false

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
    _velocity = velocity
    _update_after_physics(delta)

## Teleport the player to a spawn position and emit analytics hooks
## 
## Instantly moves the player to the specified position, resets velocity to zero,
## and emits both direct signals and EventBus events for systems that need to
## track player spawning events.
## 
## [b]spawn_position:[/b] The world position where the player should be spawned
## 
## [b]Usage:[/b]
## [codeblock]
## # Spawn player at checkpoint
## player_controller.spawn(Vector2(100, 200))
## 
## # Spawn player at last save point
## var save_point = get_save_point_position()
## player_controller.spawn(save_point)
## [/codeblock]
func spawn(spawn_position: Vector2) -> void:
    global_position = spawn_position
    _velocity = Vector2.ZERO
    
    # Emit direct signal for immediate listeners
    player_spawned.emit(spawn_position)
    
    # Emit EventBus event for decoupled systems
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
    var input_service: Node = _get_autoload_singleton(StringName("InputService"))
    if input_service and input_service.has_method("enable_context"):
        input_service.call("enable_context", "gameplay", enabled)

func is_platformer_mode() -> bool:
    return movement_config != null and movement_config.movement_mode == 0  # MovementMode.PLATFORMER

func is_top_down_mode() -> bool:
    return movement_config != null and movement_config.movement_mode == 1  # MovementMode.TOP_DOWN

## Get the current movement input vector
## 
## Returns the processed movement input based on either manual input mode
## or sampled input from InputService. The input is normalized and deadzone
## is applied to prevent drift from analog sticks.
## 
## [b]Returns:[/b] Normalized Vector2 representing movement direction (-1 to 1 range)
## 
## [b]Usage:[/b]
## [codeblock]
## # Get movement input for character movement
## var movement_input = player_controller.get_movement_input()
## velocity.x = movement_input.x * speed
## velocity.y = movement_input.y * speed
## [/codeblock]
func get_movement_input() -> Vector2:
    var input_vector: Vector2 = manual_input_vector if manual_input_enabled else _sample_input()
    
    # Normalize input to prevent diagonal movement from being faster
    if input_vector.length() > 1.0:
        input_vector = input_vector.normalized()
    
    return _apply_deadzone(input_vector)

## Apply horizontal movement for platformer mode
## 
## Handles horizontal acceleration, deceleration, and friction for platformer
## movement. Uses different acceleration values for ground vs air movement
## and applies friction when no input is provided.
## 
## [b]input_dir:[/b] Horizontal input direction (-1.0 to 1.0)
## [b]delta:[/b] Time elapsed since last frame
## [b]is_airborne:[/b] Whether the player is in the air (affects acceleration)
## 
## [b]Usage:[/b]
## [codeblock]
## # In a movement state
## var input_dir = get_movement_input().x
## var is_airborne = not is_on_floor()
## move_platformer_horizontal(input_dir, delta, is_airborne)
## [/codeblock]
func move_platformer_horizontal(input_dir: float, delta: float, is_airborne: bool) -> void:
    var target_speed: float = input_dir * movement_config.max_speed
    var acceleration: float = movement_config.air_acceleration if is_airborne else movement_config.acceleration
    var deceleration: float = movement_config.air_deceleration if is_airborne else movement_config.deceleration
    
    # Apply acceleration or deceleration based on current vs target speed
    if abs(target_speed) > abs(_velocity.x):
        _velocity.x = move_toward(_velocity.x, target_speed, acceleration * delta)
    else:
        _velocity.x = move_toward(_velocity.x, target_speed, deceleration * delta)
    
    # Apply friction when on ground with no input
    if not is_airborne and is_equal_approx(input_dir, 0.0) and movement_config.friction > 0.0:
        _velocity.x = move_toward(_velocity.x, 0.0, movement_config.friction * delta)

## Apply movement for top-down mode
## 
## Handles 2D movement in all directions for top-down games. Applies
## acceleration/deceleration to both X and Y axes independently and
## applies friction when no input is provided.
## 
## [b]input_vector:[/b] 2D input direction vector (-1 to 1 range)
## [b]delta:[/b] Time elapsed since last frame
## 
## [b]Usage:[/b]
## [codeblock]
## # In a top-down movement state
## var input_vector = get_movement_input()
## move_top_down(input_vector, delta)
## [/codeblock]
func move_top_down(input_vector: Vector2, delta: float) -> void:
    var target_velocity: Vector2 = input_vector * movement_config.max_speed
    
    # Apply movement to both axes independently
    _velocity.x = _move_component(_velocity.x, target_velocity.x, delta, movement_config.acceleration, movement_config.deceleration)
    _velocity.y = _move_component(_velocity.y, target_velocity.y, delta, movement_config.acceleration, movement_config.deceleration)
    
    # Apply friction when no input is provided
    if input_vector.length_squared() == 0.0 and movement_config.friction > 0.0:
        _velocity.x = move_toward(_velocity.x, 0.0, movement_config.friction * delta)
        _velocity.y = move_toward(_velocity.y, 0.0, movement_config.friction * delta)

## Apply gravity to vertical velocity
## 
## Applies downward gravity force to the player's vertical velocity.
## Only works in platformer mode and respects maximum fall speed.
## 
## [b]delta:[/b] Time elapsed since last frame
## 
## [b]Usage:[/b]
## [codeblock]
## # In platformer physics update
## if not is_on_floor():
##     apply_gravity(delta)
## [/codeblock]
func apply_gravity(delta: float) -> void:
    if not is_platformer_mode():
        return
    
    # Apply gravity force
    _velocity.y += movement_config.gravity * delta
    
    # Clamp to maximum fall speed
    if _velocity.y > movement_config.max_fall_speed:
        _velocity.y = movement_config.max_fall_speed

## Execute a jump by setting vertical velocity
## 
## Sets the player's vertical velocity to the configured jump velocity
## and emits jump events. Also clears jump buffer and coyote timers
## to prevent double jumping.
## 
## [b]Usage:[/b]
## [codeblock]
## # When jump is triggered
## if can_jump():
##     start_jump()
## [/codeblock]
func start_jump() -> void:
    _velocity.y = movement_config.jump_velocity
    
    # Emit jump events
    player_jumped.emit()
    _emit_player_event(EventTopics.PLAYER_JUMPED, {} as Dictionary[StringName, Variant])
    
    # Clear jump timers to prevent double jumping
    _jump_buffer_timer = 0.0
    _coyote_timer = 0.0

## Check and consume a jump request if valid
## 
## Validates jump conditions including platformer mode, jump allowance,
## jump buffer timing, and coyote time. Consumes the jump request
## by clearing timers if conditions are met.
## 
## [b]Returns:[/b] true if jump request was valid and consumed, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## # Check if player can jump
## if consume_jump_request():
##     start_jump()
## [/codeblock]
func consume_jump_request() -> bool:
    # Check if jumping is allowed in this mode
    if not is_platformer_mode() or not movement_config.allow_jump:
        return false
    
    # Check if jump was recently requested (buffer window)
    if _jump_buffer_timer <= 0.0:
        return false
    
    # Check if player is on ground or within coyote time
    if not is_on_floor() and _coyote_timer <= 0.0:
        return false
    
    # Consume the jump request
    _jump_buffer_timer = 0.0
    _coyote_timer = 0.0
    return true

## Refresh the coyote time timer
## 
## Sets the coyote timer to the configured coyote time duration.
## Only works in platformer mode. Coyote time allows jumping briefly
## after leaving a platform.
## 
## [b]Usage:[/b]
## [codeblock]
## # When player leaves ground
## if was_on_floor and not is_on_floor():
##     refresh_coyote_timer()
## [/codeblock]
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

## Register a new ability with the player
## 
## Adds an ability to the player's ability system. The ability will
## be set up with the player as its owner and can be activated/deactivated.
## 
## [b]ability_id:[/b] Unique identifier for the ability
## [b]ability:[/b] Node containing the ability logic
## 
## [b]Usage:[/b]
## [codeblock]
## # Register a dash ability
## var dash_ability = preload("res://abilities/DashAbility.gd").new()
## player_controller.register_ability("dash", dash_ability)
## [/codeblock]
func register_ability(ability_id: StringName, ability: Node) -> void:
    if _abilities.has(ability_id):
        push_warning("Ability '%s' is already registered" % ability_id)
        return

    # Set up the ability with this player as owner
    ability.setup(self, ability_id)
    _abilities[ability_id] = ability
    
    # Notify listeners that ability was registered
    ability_registered.emit(ability_id, ability)

## Unregister an ability from the player
## 
## Removes an ability from the player's ability system. The ability
## will be deactivated and removed from the abilities dictionary.
## 
## [b]ability_id:[/b] Unique identifier of the ability to remove
## 
## [b]Usage:[/b]
## [codeblock]
## # Remove a temporary ability
## player_controller.unregister_ability("temporary_power")
## [/codeblock]
func unregister_ability(ability_id: StringName) -> void:
    if not _abilities.has(ability_id):
        push_warning("Ability '%s' is not registered" % ability_id)
        return

    var ability: Node = _abilities[ability_id]
    _abilities.erase(ability_id)
    
    # Deactivate the ability before removing
    ability.deactivate()
    
    # Notify listeners that ability was unregistered
    ability_unregistered.emit(ability_id)

## Get an ability by its ID
## 
## Retrieves a registered ability from the player's ability system.
## 
## [b]ability_id:[/b] Unique identifier of the ability
## 
## [b]Returns:[/b] The ability Node if found, null otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## # Check if ability exists before using
## var dash_ability = player_controller.get_ability("dash")
## if dash_ability:
##     dash_ability.activate()
## [/codeblock]
func get_ability(ability_id: StringName) -> Node:
    return _abilities.get(ability_id, null)

## Activate an ability
## 
## Activates a registered ability if it exists.
## 
## [b]ability_id:[/b] Unique identifier of the ability to activate
## 
## [b]Usage:[/b]
## [codeblock]
## # Activate dash ability
## player_controller.activate_ability("dash")
## [/codeblock]
func activate_ability(ability_id: StringName) -> void:
    var ability: Node = get_ability(ability_id)
    if ability:
        ability.activate()

## Deactivate an ability
## 
## Deactivates a registered ability if it exists.
## 
## [b]ability_id:[/b] Unique identifier of the ability to deactivate
## 
## [b]Usage:[/b]
## [codeblock]
## # Deactivate temporary ability
## player_controller.deactivate_ability("shield")
## [/codeblock]
func deactivate_ability(ability_id: StringName) -> void:
    var ability: Node = get_ability(ability_id)
    if ability:
        ability.deactivate()

# Combat/Damage System - Delegates to HealthComponent
## Apply damage to the player
## 
## Deals damage to the player using the HealthComponent system.
## Supports different damage types and tracks the damage source.
## 
## [b]amount:[/b] Amount of damage to deal
## [b]source:[/b] Node that caused the damage (optional)
## [b]damage_type:[/b] Type of damage ("physical", "magical", "fire", etc.)
## 
## [b]Usage:[/b]
## [codeblock]
## # Deal physical damage from an enemy
## player_controller.take_damage(25.0, enemy, "physical")
## 
## # Deal fire damage from a trap
## player_controller.take_damage(10.0, trap, "fire")
## [/codeblock]
func take_damage(amount: float, source: Node = null, damage_type: String = "physical") -> void:
    if not _health_component:
        push_error("HealthComponent not available")
        return

    var damage_info: DamageInfo = DamageInfoScript.create_damage(amount, _get_damage_type_enum(damage_type), source)
    _health_component.take_damage(damage_info)

## Heal the player
## 
## Restores health to the player using the HealthComponent system.
## Tracks the healing source for analytics and effects.
## 
## [b]amount:[/b] Amount of health to restore
## [b]source:[/b] Node that provided the healing (optional)
## 
## [b]Usage:[/b]
## [codeblock]
## # Heal from a health potion
## player_controller.heal(50.0, health_potion)
## 
## # Heal from a checkpoint
## player_controller.heal(100.0, checkpoint)
## [/codeblock]
func heal(amount: float, source: Node = null) -> void:
    if not _health_component:
        push_error("HealthComponent not available")
        return

    var healing_info: DamageInfo = DamageInfoScript.create_healing(amount, source)
    _health_component.heal(healing_info)

## Kill the player immediately
## 
## Instantly kills the player regardless of current health.
## Useful for instant death scenarios like falling into pits.
## 
## [b]source:[/b] Node that caused the death (optional)
## 
## [b]Usage:[/b]
## [codeblock]
## # Kill player from falling
## if player_position.y > death_height:
##     player_controller.die(fall_trigger)
## [/codeblock]
func die(source: Node = null) -> void:
    if _health_component:
        _health_component.kill(source)

## Set the maximum health value
## 
## Updates the player's maximum health. This affects the health bar
## display and healing calculations.
## 
## [b]new_max:[/b] New maximum health value
## 
## [b]Usage:[/b]
## [codeblock]
## # Increase max health from upgrade
## player_controller.set_max_health(150.0)
## [/codeblock]
func set_max_health(new_max: float) -> void:
    if _health_component:
        _health_component.max_health = new_max

## Get current health value
## 
## Returns the player's current health points.
## 
## [b]Returns:[/b] Current health value (0.0 to max_health)
## 
## [b]Usage:[/b]
## [codeblock]
## # Check if player is low on health
## if player_controller.get_health() < 25.0:
##     show_low_health_warning()
## [/codeblock]
func get_health() -> float:
    return _health_component.get_health() if _health_component else 0.0

## Get maximum health value
## 
## Returns the player's maximum health points.
## 
## [b]Returns:[/b] Maximum health value
## 
## [b]Usage:[/b]
## [codeblock]
## # Calculate health percentage
## var health_percent = player_controller.get_health() / player_controller.get_max_health()
## [/codeblock]
func get_max_health() -> float:
    return _health_component.get_max_health() if _health_component else 0.0

## Get health as a percentage
## 
## Returns the player's health as a percentage from 0.0 to 1.0.
## 
## [b]Returns:[/b] Health percentage (0.0 = dead, 1.0 = full health)
## 
## [b]Usage:[/b]
## [codeblock]
## # Update health bar
## health_bar.value = player_controller.get_health_percentage()
## [/codeblock]
func get_health_percentage() -> float:
    return _health_component.get_health_percentage() if _health_component else 0.0

## Check if the player is alive
## 
## Returns whether the player is currently alive (health > 0).
## 
## [b]Returns:[/b] true if player is alive, false if dead
## 
## [b]Usage:[/b]
## [codeblock]
## # Check before allowing actions
## if player_controller.is_alive():
##     allow_player_input()
## [/codeblock]
func is_alive() -> bool:
    return _health_component.is_alive() if _health_component else false

## Check if the player has full health
## 
## Returns whether the player's health is at maximum.
## 
## [b]Returns:[/b] true if health is at maximum, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## # Prevent healing when at full health
## if not player_controller.is_full_health():
##     use_health_potion()
## [/codeblock]
func is_full_health() -> bool:
    return _health_component.is_full_health() if _health_component else false

## Make the player invulnerable for a specified duration
## 
## Grants temporary invulnerability to the player, preventing
## all damage for the specified duration.
## 
## [b]duration:[/b] Duration of invulnerability in seconds
## 
## [b]Usage:[/b]
## [codeblock]
## # Grant invulnerability after taking damage
## player_controller.set_invulnerable(2.0)
## [/codeblock]
func set_invulnerable(duration: float) -> void:
    if _health_component:
        _health_component.set_invulnerable(true, duration)

## Check if the player is currently invulnerable
## 
## Returns whether the player is currently immune to damage.
## 
## [b]Returns:[/b] true if invulnerable, false if vulnerable
## 
## [b]Usage:[/b]
## [codeblock]
## # Skip damage if invulnerable
## if not player_controller.is_invulnerable():
##     player_controller.take_damage(damage_amount)
## [/codeblock]
func is_invulnerable() -> bool:
    return _health_component.is_invulnerable() if _health_component else false

## Convert string damage type to enum value
## 
## Maps string damage type names to their corresponding enum values.
## Case-insensitive matching with fallback to physical damage.
## 
## [b]damage_type:[/b] String name of the damage type
## 
## [b]Returns:[/b] Corresponding DamageType enum value
func _get_damage_type_enum(damage_type: String) -> int:
    match damage_type.to_lower():
        "physical": 
            return DamageInfoScript.DamageType.PHYSICAL
        "magical", "magic": 
            return DamageInfoScript.DamageType.MAGICAL
        "fire": 
            return DamageInfoScript.DamageType.FIRE
        "ice": 
            return DamageInfoScript.DamageType.ICE
        "lightning": 
            return DamageInfoScript.DamageType.LIGHTNING
        "poison": 
            return DamageInfoScript.DamageType.POISON
        "true": 
            return DamageInfoScript.DamageType.TRUE
        "healing": 
            return DamageInfoScript.DamageType.HEALING
        _: 
            return DamageInfoScript.DamageType.PHYSICAL

# Save/Load System - ISaveable Implementation
## Save player state for persistence
## 
## Serializes the player's current state including position, velocity,
## state machine state, abilities, and health data for saving to disk.
## 
## [b]Returns:[/b] Dictionary containing all player state data
## 
## [b]Usage:[/b]
## [codeblock]
## # Save player state
## var player_data = player_controller.save_data()
## save_file.store_string(JSON.stringify(player_data))
## [/codeblock]
func save_data() -> Dictionary:
    var health_data: Dictionary = {}
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

## Load player state from saved data
## 
## Restores the player's state from previously saved data including
## position, velocity, state machine state, abilities, and health.
## 
## [b]data:[/b] Dictionary containing saved player state data
## 
## [b]Returns:[/b] true if loading was successful, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## # Load player state
## var player_data = JSON.parse_string(save_file.get_as_text())
## player_controller.load_data(player_data)
## [/codeblock]
func load_data(data: Dictionary) -> bool:
    if not data.has("position"):
        return false

    # Load position
    var pos_data: Dictionary = data.position
    global_position = Vector2(
        pos_data.get("x", 0.0),
        pos_data.get("y", 0.0)
    )

    # Load velocity
    if data.has("velocity"):
        var vel_data: Dictionary = data.velocity
        _velocity = Vector2(
            vel_data.get("x", 0.0),
            vel_data.get("y", 0.0)
        )

    # Load state machine state
    var saved_state: String = data.get("current_state", "")
    if _state_machine and saved_state != "":
        _state_machine.transition_to(StringName(saved_state), {})

    # Load abilities
    var abilities_data: Dictionary = data.get("abilities", {})
    _load_abilities_data(abilities_data)

    # Load health data (delegate to HealthComponent)
    var health_data: Dictionary = data.get("health_data", {})
    if _health_component and not health_data.is_empty():
        _health_component.load_data(health_data)

    return true

## Get unique identifier for this saveable object
## 
## Returns the unique string identifier used by SaveService
## to identify this player controller in save files.
## 
## [b]Returns:[/b] Unique string identifier
func get_save_id() -> String:
    return "player_controller"

## Get save priority for ordering
## 
## Returns the priority value for save/load ordering.
## Lower numbers are saved/loaded first.
## 
## [b]Returns:[/b] Priority value (10 = high priority)
func get_save_priority() -> int:
    return 10  # High priority - save player state early

## Get data for active abilities
## 
## Collects save data from all currently active abilities.
## 
## [b]Returns:[/b] Dictionary containing ability states and custom data
func _get_active_abilities_data() -> Dictionary:
    var data: Dictionary = {}
    for ability_id in _abilities:
        var ability: Node = _abilities[ability_id]
        if ability.is_active():
            data[ability_id] = {
                "active": true,
                "custom_data": ability.save_data() if ability.has_method("save_data") else {}
            }
    return data

## Load abilities from saved data
## 
## Restores ability states and custom data from saved data.
## 
## [b]abilities_data:[/b] Dictionary containing saved ability data
func _load_abilities_data(abilities_data: Dictionary) -> void:
    for ability_id in abilities_data:
        var ability_data: Dictionary = abilities_data[ability_id]
        var ability: Node = get_ability(StringName(ability_id))
        if ability:
            var was_active: bool = ability_data.get("active", false)
            if was_active:
                ability.activate()
            else:
                ability.deactivate()

            # Load custom ability data
            var custom_data: Dictionary = ability_data.get("custom_data", {})
            if ability.has_method("load_data"):
                ability.load_data(custom_data)

## Resolve and initialize the state machine
## 
## Sets up the state machine by finding or creating it, registering
## built-in states, connecting signals, and transitioning to idle state.
func _resolve_state_machine() -> void:
    if state_machine_path.is_empty():
        _ensure_state_machine_child()

    var node: Node = null
    if not state_machine_path.is_empty():
        node = get_node_or_null(state_machine_path)

    if node == null:
        _ensure_state_machine_child()
        if state_machine_path.is_empty():
            return
        node = get_node_or_null(state_machine_path)

    if node is StateMachine:
        _state_machine = node
        _register_builtin_states()
        _refresh_state_context()

        # Connect state machine signals
        if not _state_machine.state_changed.is_connected(_on_state_changed):
            _state_machine.state_changed.connect(_on_state_changed)
        if not _state_machine.state_event.is_connected(_on_state_event):
            _state_machine.state_event.connect(_on_state_event)

        # Ensure current state instance is initialized with the latest context
        var current: StringName = _state_machine.get_current_state()
        if current == StringName():
            current = STATE_IDLE
        _state_machine.transition_to(current)

## Ensure state machine child exists
## 
## Creates a state machine child node if one doesn't exist.
## Updates the state_machine_path to point to the created node.
func _ensure_state_machine_child() -> void:
    if state_machine_path.is_empty():
        var existing: Node = find_child("StateMachine", true, false)
        if existing is StateMachine:
            state_machine_path = existing.get_path()
            return
            
        var machine: StateMachine = StateMachineScript.new() as StateMachine
        machine.name = "StateMachine"
        add_child(machine)
        await machine.ready
        state_machine_path = machine.get_path()

## Register built-in movement states
## 
## Registers the core movement states (idle, move, jump, fall) with
## the state machine. Platformer-specific states are only registered
## in platformer mode.
func _register_builtin_states() -> void:
    if _state_machine == null:
        return
        
    # Always register basic states
    if not _state_machine.has_state(STATE_IDLE):
        _state_machine.register_state(STATE_IDLE, IdleStateScript)
    if not _state_machine.has_state(STATE_MOVE):
        _state_machine.register_state(STATE_MOVE, MoveStateScript)
        
    # Register platformer-specific states
    if is_platformer_mode():
        if not _state_machine.has_state(STATE_JUMP):
            _state_machine.register_state(STATE_JUMP, JumpStateScript)
        if not _state_machine.has_state(STATE_FALL):
            _state_machine.register_state(STATE_FALL, FallStateScript)
    else:
        # Remove platformer states in top-down mode
        _state_machine.unregister_state(STATE_JUMP)
        _state_machine.unregister_state(STATE_FALL)
        
    # Ensure we have a valid current state
    var current: StringName = _state_machine.get_current_state()
    if current == StringName() or not _state_machine.has_state(current):
        _state_machine.transition_to(STATE_IDLE)

## Refresh state machine context
## 
## Updates the state machine context with current movement config
## and controller reference. Also ensures built-in states are registered.
func _refresh_state_context() -> void:
    if _state_machine == null:
        return
        
    var context: Dictionary[StringName, Variant] = {
        StringName("movement_config"): movement_config,
        StringName("controller"): self
    }
    _state_machine.set_context(context)
    _register_builtin_states()

## Sample input from InputService
## 
## Retrieves movement input from the InputService via stored axis values.
## Handles vertical input restrictions and provides graceful fallback.
## 
## [b]Returns:[/b] Vector2 representing movement input (-1 to 1 range)
func _sample_input() -> Vector2:
    if movement_config == null:
        return Vector2.ZERO
    
    var x: float = 0.0
    var y: float = 0.0
    
    # Try InputService first
    if _input_service_connected and not _axis_values.is_empty():
        x = clamp(_axis_values.get(StringName("move_x"), 0.0), -1.0, 1.0)
        y = clamp(_axis_values.get(StringName("move_y"), 0.0), -1.0, 1.0)
    else:
        # Fallback to direct input
        if movement_config.use_axis_input:
            x = Input.get_axis(movement_config.axis_negative_action, movement_config.axis_positive_action)
            y = Input.get_axis(movement_config.axis_vertical_negative_action, movement_config.axis_vertical_positive_action)
        else:
            # Use individual actions
            if Input.is_action_pressed(movement_config.move_left_action):
                x -= 1.0
            if Input.is_action_pressed(movement_config.move_right_action):
                x += 1.0
            if Input.is_action_pressed(movement_config.move_up_action):
                y -= 1.0
            if Input.is_action_pressed(movement_config.move_down_action):
                y += 1.0

        # Ensure jump/interact still work without InputService
        if Input.is_action_just_pressed(movement_config.jump_action):
            _record_jump_buffer()
        if Input.is_action_just_pressed(movement_config.interact_action):
            interact()

    if not movement_config.allow_vertical_input:
        y = 0.0

    if not _input_service_connected and _axis_values.is_empty() and not _warned_missing_input_service:
        push_warning("PlayerController: InputService autoload not found, using direct input fallback")
        _warned_missing_input_service = true

    return Vector2(x, y)

## Apply deadzone to input vector
## 
## Removes small input values below the deadzone threshold to prevent
## drift from analog sticks and improve input responsiveness.
## 
## [b]input_vector:[/b] Raw input vector from input device
## 
## [b]Returns:[/b] Input vector with deadzone applied
func _apply_deadzone(input_vector: Vector2) -> Vector2:
    var deadzone: float = movement_config.movement_input_deadzone if movement_config else 0.0
    if deadzone <= 0.0:
        return input_vector
        
    return Vector2(
        0.0 if abs(input_vector.x) < deadzone else input_vector.x,
        0.0 if abs(input_vector.y) < deadzone else input_vector.y
    )

## Move a single component (x or y) toward target value
## 
## Applies acceleration or deceleration to move a velocity component
## toward its target value based on whether we're speeding up or slowing down.
## 
## [b]current:[/b] Current velocity component value
## [b]target:[/b] Target velocity component value
## [b]delta:[/b] Time elapsed since last frame
## [b]accel:[/b] Acceleration rate when speeding up
## [b]decel:[/b] Deceleration rate when slowing down
## 
## [b]Returns:[/b] New velocity component value
func _move_component(current: float, target: float, delta: float, accel: float, decel: float) -> float:
    if abs(target) > abs(current):
        return move_toward(current, target, accel * delta)
    return move_toward(current, target, decel * delta)

## Update physics-related state after movement
## 
## Handles post-physics updates including jump buffering, coyote time,
## and landing detection. Only applies to platformer mode.
## 
## [b]delta:[/b] Time elapsed since last frame
func _update_after_physics(delta: float) -> void:
    if not is_platformer_mode():
        # In top-down mode, always consider player "on floor"
        _jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
        _was_on_floor = true
        return
        
    var on_floor: bool = is_on_floor()
    
    # Detect landing
    if on_floor and not _was_on_floor:
        player_landed.emit()
        _emit_player_event(EventTopics.PLAYER_LANDED, {} as Dictionary[StringName, Variant])
    
    # Update coyote timer
    if on_floor:
        _coyote_timer = movement_config.coyote_time
    else:
        _coyote_timer = max(_coyote_timer - delta, 0.0)
    
    # Update jump buffer timer
    _jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
    _was_on_floor = on_floor

## Register this player controller with the SaveService
## 
## Registers the player controller as a saveable object with the SaveService
## so it can be included in save/load operations.
func _register_with_save_service() -> void:
    var save_service: Node = _get_autoload_singleton(StringName("SaveService"))
    if save_service and save_service.has_method("register_saveable"):
        save_service.call("register_saveable", self)

## Connect to InputService signals
## 
## Establishes connections to InputService for action and axis events.
## Also enables the gameplay input context.
func _connect_input_service() -> void:
    if Engine.is_editor_hint() or _input_service_connected:
        return
        
    var input_service: Node = _get_autoload_singleton(StringName("InputService"))
    if input_service == null:
        push_warning("PlayerController: InputService autoload not found, input disabled")
        return

    var action_callable := Callable(self, "_on_action_event")
    var axis_callable := Callable(self, "_on_axis_event")

    if input_service.has_signal("action_event") and not input_service.is_connected("action_event", action_callable):
        input_service.connect("action_event", action_callable)
        _input_service_connected = true
    if input_service.has_signal("axis_event") and not input_service.is_connected("axis_event", axis_callable):
        input_service.connect("axis_event", axis_callable)
        _input_service_connected = true
    if input_service.has_method("enable_context"):
        input_service.call("enable_context", "gameplay", true)
    if _input_service_connected:
        _warned_missing_input_service = false

## Disconnect from InputService signals
## 
## Removes connections to InputService to prevent memory leaks.
func _disconnect_input_service() -> void:
    if not _input_service_connected or Engine.is_editor_hint():
        return
        
    var input_service: Node = _get_autoload_singleton(StringName("InputService"))
    if input_service:
        var action_callable := Callable(self, "_on_action_event")
        var axis_callable := Callable(self, "_on_axis_event")
        if input_service.has_signal("action_event") and input_service.is_connected("action_event", action_callable):
            input_service.disconnect("action_event", action_callable)
        if input_service.has_signal("axis_event") and input_service.is_connected("axis_event", axis_callable):
            input_service.disconnect("axis_event", axis_callable)
    _input_service_connected = false

func _connect_eventbus_input() -> void:
    """Connect to EventBus input events as primary input source."""
    if Engine.is_editor_hint():
        return
    var event_bus: Node = _get_autoload_singleton(StringName("EventBus"))
    if event_bus and event_bus.has_method("sub"):
        # Subscribe to input events from EventBus
        event_bus.call("sub", EventTopics.INPUT_ACTION, Callable(self, "_on_eventbus_action"))
        event_bus.call("sub", EventTopics.INPUT_AXIS, Callable(self, "_on_eventbus_axis"))

func _disconnect_eventbus_input() -> void:
    """Disconnect from EventBus input events."""
    if Engine.is_editor_hint():
        return
    var event_bus: Node = _get_autoload_singleton(StringName("EventBus"))
    if event_bus and event_bus.has_method("unsub"):
        event_bus.call("unsub", EventTopics.INPUT_ACTION, Callable(self, "_on_eventbus_action"))
        event_bus.call("unsub", EventTopics.INPUT_AXIS, Callable(self, "_on_eventbus_axis"))

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

## Record a jump request in the buffer
## 
## Stores a jump request that can be consumed later if the player
## becomes able to jump (e.g., lands on ground or within coyote time).
func _record_jump_buffer() -> void:
    if not is_platformer_mode() or not movement_config.allow_jump:
        return
    _jump_buffer_timer = movement_config.jump_buffer_time

## Handle state machine state changes
## 
## Emits state change events and notifies abilities when the
## player's movement state changes.
## 
## [b]previous:[/b] Previous state name
## [b]current:[/b] Current state name
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

## Handle state machine events
## 
## Forwards state machine events to the player controller and abilities.
## 
## [b]event:[/b] Event name from state machine
## [b]data:[/b] Event data from state machine
func _on_state_event(event: StringName, data: Variant) -> void:
    state_event.emit(event, data)

    # Forward to abilities
    for ability in _abilities.values():
        ability.handle_state_event(event, data)

## Emit a player event to EventBus
## 
## Publishes a player-related event to the EventBus with timestamp.
## 
## [b]topic:[/b] Event topic to publish
## [b]payload:[/b] Event data dictionary
func _emit_player_event(topic: StringName, payload: Dictionary[StringName, Variant]) -> void:
    var event_bus: Node = _get_autoload_singleton(StringName("EventBus"))
    if event_bus and event_bus.has_method("pub"):
        payload[StringName("timestamp_ms")] = Time.get_ticks_msec()
        event_bus.call("pub", topic, payload)

func _connect_eventbus_health() -> void:
    """Connect to EventBus health events for player-specific handling."""
    if Engine.is_editor_hint():
        return
    var event_bus: Node = _get_autoload_singleton(StringName("EventBus"))
    if event_bus and event_bus.has_method("sub"):
        # Subscribe to combat events for this player
        event_bus.call("sub", EventTopics.COMBAT_HIT, Callable(self, "_on_eventbus_damage"))
        event_bus.call("sub", EventTopics.COMBAT_HEAL, Callable(self, "_on_eventbus_heal"))
        event_bus.call("sub", EventTopics.COMBAT_ENTITY_DEATH, Callable(self, "_on_eventbus_death"))

func _disconnect_eventbus_health() -> void:
    """Disconnect from EventBus health events."""
    if Engine.is_editor_hint():
        return
    var event_bus: Node = _get_autoload_singleton(StringName("EventBus"))
    if event_bus and event_bus.has_method("unsub"):
        event_bus.call("unsub", EventTopics.COMBAT_HIT, Callable(self, "_on_eventbus_damage"))
        event_bus.call("unsub", EventTopics.COMBAT_HEAL, Callable(self, "_on_eventbus_heal"))
        event_bus.call("unsub", EventTopics.COMBAT_ENTITY_DEATH, Callable(self, "_on_eventbus_death"))

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

func _get_autoload_singleton(name: StringName) -> Node:
    var cached: Node = _autoload_cache.get(name)
    if is_instance_valid(cached):
        return cached

    if not is_instance_valid(get_tree()):
        return null

    var root: Node = get_tree().root
    if root == null:
        return null

    var name_str := String(name)
    var node: Node = root.get_node_or_null(NodePath(name_str))

    if node == null:
        var abs_path := NodePath("/root/%s" % name_str)
        node = root.get_node_or_null(abs_path)

    if node == null:
        for child in root.get_children():
            if String(child.name) == name_str:
                node = child
                break

    if node:
        _autoload_cache[name] = node
    return node
