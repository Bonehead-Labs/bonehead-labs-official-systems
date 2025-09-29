extends CharacterBody2D

## Node-driven base enemy with FSM, health, hitbox, hurtbox and perception

@export var move_speed: float = 100.0
@export var chase_speed: float = 120.0
@export var attack_range: float = 50.0
@export var initial_state: StringName = &"idle"

@export_node_path("Sprite2D") var sprite_path: NodePath
@export_node_path("AnimatedSprite2D") var animated_sprite_path: NodePath
@export_node_path("Area2D") var perception_area_path: NodePath = ^"PerceptionArea"
@export_node_path("Node") var state_machine_path: NodePath = ^"StateMachine"
@export_node_path("Node") var health_component_path: NodePath = ^"HealthComponent"
@export_node_path("Area2D") var hurtbox_path: NodePath = ^"HurtboxComponent"
@export_node_path("Area2D") var hitbox_path: NodePath = ^"HitboxComponent"

var _sprite: Sprite2D
var _anim: AnimatedSprite2D
var _perception: Area2D
var _state_machine: Node
var _health_component: Node
var _hurtbox_component: Area2D
var _hitbox_component: Area2D

var _alert_target: Node2D = null

const StateMachineScript = preload("res://systems/fsm/StateMachine.gd")
const IdleStateScript = preload("res://EnemyAI/states/EnemyIdleState.gd")
const PatrolStateScript = preload("res://EnemyAI/states/PatrolState.gd")
const ChaseStateScript = preload("res://EnemyAI/states/ChaseState.gd")

func _ready() -> void:
	_resolve_nodes()
	_setup_state_machine()
	_setup_perception()

func _physics_process(delta: float) -> void:
	if _state_machine and _state_machine.has_method("physics_update_state"):
		_state_machine.call("physics_update_state", delta)
	move_and_slide()

func _resolve_nodes() -> void:
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	_anim = get_node_or_null(animated_sprite_path) as AnimatedSprite2D
	_perception = get_node_or_null(perception_area_path) as Area2D
	_state_machine = get_node_or_null(state_machine_path)
	_health_component = get_node_or_null(health_component_path)
	_hurtbox_component = get_node_or_null(hurtbox_path) as Area2D
	_hitbox_component = get_node_or_null(hitbox_path) as Area2D

	if _state_machine == null:
		_state_machine = Node.new()
		_state_machine.name = "StateMachine"
		add_child(_state_machine)
		_state_machine.set_script(StateMachineScript)

func _setup_state_machine() -> void:
	# Attach script if missing
	if not _state_machine.get_script():
		_state_machine.set_script(StateMachineScript)

	# Register base states (reusing existing EnemyAI states)
	if _state_machine.has_method("register_state"):
		_state_machine.call("register_state", &"idle", IdleStateScript)
		_state_machine.call("register_state", &"patrol", PatrolStateScript)
		_state_machine.call("register_state", &"chase", ChaseStateScript)

	# Set typed context
	var ctx: Dictionary[StringName, Variant] = {
		&"enemy": self,
		&"health_component": _health_component,
		&"hurtbox_component": _hurtbox_component,
		&"hitbox_component": _hitbox_component,
		&"move_speed": move_speed,
		&"chase_speed": chase_speed,
		&"attack_range": attack_range
	}
	if _state_machine.has_method("set_context"):
		_state_machine.call("set_context", ctx)

	# Initial state property and transition
	_state_machine.set("initial_state", initial_state)
	if _state_machine.has_method("transition_to") and initial_state != StringName():
		_state_machine.call("transition_to", initial_state)

func _setup_perception() -> void:
	if _perception == null:
		return
	if not _perception.body_entered.is_connected(_on_perception_body_entered):
		_perception.body_entered.connect(_on_perception_body_entered)
	if not _perception.body_exited.is_connected(_on_perception_body_exited):
		_perception.body_exited.connect(_on_perception_body_exited)

func _on_perception_body_entered(body: Node) -> void:
	var as_node2d := body as Node2D
	if as_node2d == null:
		return
	if _is_player(as_node2d):
		_alert_target = as_node2d
		if _state_machine and _state_machine.has_method("transition_to"):
			_state_machine.call("transition_to", &"move")

func _on_perception_body_exited(body: Node) -> void:
	if body == _alert_target:
		_alert_target = null
		if _state_machine and _state_machine.has_method("transition_to"):
			_state_machine.call("transition_to", &"idle")

func get_alert_target() -> Node2D:
	return _alert_target

func can_attack_target(target: Node2D) -> bool:
	if target == null:
		return false
	return global_position.distance_to(target.global_position) <= attack_range

func move_toward_position(target_position: Vector2, speed: float) -> void:
	var dir := (target_position - global_position).normalized()
	velocity = dir * speed

func stop_moving() -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 800.0 * get_physics_process_delta_time())

func _is_player(body: Node2D) -> bool:
	if body.is_in_group("player"):
		return true
	if body.has_method("player"):
		return true
	return String(body.name) == "Player"


