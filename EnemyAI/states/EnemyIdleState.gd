class_name EnemyIdleState
extends FSMState

## Idle state for enemies - waits and watches for the player.

const EnemyBaseScript = preload("../EnemyBaseV2.gd")
const EnemyConfigScript = preload("../EnemyConfig.gd")

var _enemy: EnemyBase
var _config: EnemyConfig
var _idle_timer: float = 0.0
var _idle_duration: float = 2.0  # How long to stay idle before patrolling

func setup(state_machine: StateMachine, state_owner: Node, state_context: Dictionary[StringName, Variant]) -> void:
	super.setup(state_machine, state_owner, state_context)
	
	# Validate required context keys
	if not validate_context([&"enemy", &"config"]):
		return
	
	_enemy = get_context_value(&"enemy", null, TYPE_OBJECT) as EnemyBase
	_config = get_context_value(&"config", null, TYPE_OBJECT) as EnemyConfig

func enter(_payload: Dictionary[StringName, Variant] = {}) -> void:
	_idle_timer = 0.0
	_enemy.stop_moving()
	
	# Emit event
	emit_event(&"idle_started", {
		&"position": _enemy.global_position
	})

func update(delta: float) -> void:
	_idle_timer += delta
	
	# Check if we should transition to patrol after idle duration
	if _idle_timer >= _idle_duration:
		safe_transition_to(&"patrol", {}, &"idle_timeout")
		return

func physics_update(_delta: float) -> void:
	# Check for alert transitions (handled by EnemyBase)
	if _enemy.is_alerted():
		safe_transition_to(&"chase", {}, &"alerted")

func handle_event(event: StringName, _data: Variant = null) -> void:
	match event:
		&"alerted":
			safe_transition_to(&"chase", {}, &"alerted")
		&"damaged":
			safe_transition_to(&"chase", {}, &"damaged")
		&"patrol_requested":
			safe_transition_to(&"patrol", {}, &"patrol_requested")

func exit(_payload: Dictionary[StringName, Variant] = {}) -> void:
	emit_event(&"idle_ended", {
		&"duration": _idle_timer,
		&"reason": _payload.get(&"reason", &"unknown")
	})

## Set the idle duration
func set_idle_duration(duration: float) -> void:
	_idle_duration = duration

## Get current idle time
func get_idle_time() -> float:
	return _idle_timer
