class_name BaseEnemy
extends CharacterBody2D

## Node-driven base enemy with FSM, health, hitbox, hurtbox and perception

@export var move_speed: float = 100.0
@export var chase_speed: float = 120.0
@export var attack_range: float = 50.0
@export var config: EnemyConfig
@export var debug_enabled: bool = false
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
const EnemyConfigScript = preload("res://EnemyAI/EnemyConfig.gd")
const IdleStateScript = preload("res://EnemyAI/states/EnemyIdleState.gd")
const PatrolStateScript = preload("res://EnemyAI/states/PatrolState.gd")
const ChaseStateScript = preload("res://EnemyAI/states/ChaseState.gd")

func _ready() -> void:
	_resolve_nodes()
	_ensure_config()
	_setup_state_machine()
	_setup_perception()
	_connect_state_debug()
	_connect_health_death()

func _physics_process(delta: float) -> void:
	if _state_machine and _state_machine.has_method("physics_update_state"):
		_state_machine.call("physics_update_state", delta)
	move_and_slide()

func _process(delta: float) -> void:
	if _state_machine and _state_machine.has_method("update_state"):
		_state_machine.call("update_state", delta)

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

func _ensure_config() -> void:
	if config == null:
		config = EnemyConfigScript.create_basic_enemy()

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
		&"config": config,
		&"health_component": _health_component,
		&"hurtbox_component": _hurtbox_component,
		&"hitbox_component": _hitbox_component,
		&"move_speed": move_speed,
		&"chase_speed": chase_speed,
		&"attack_range": attack_range
	}
	if _state_machine.has_method("set_context"):
		_state_machine.call("set_context", ctx)
		if debug_enabled:
			print("[EnemyBaseV2] Context set:", {
				"has_enemy": ctx.has(&"enemy"),
				"has_config": ctx.has(&"config"),
				"initial_state": initial_state
			})

	# Initial state property and transition
	_state_machine.set("initial_state", initial_state)
	if _state_machine.has_method("transition_to") and initial_state != StringName():
		_state_machine.call("transition_to", initial_state)
		if debug_enabled:
			print("[EnemyBaseV2] Transitioned to initial state:", initial_state)

func _setup_perception() -> void:
	if _perception == null:
		return
	if not _perception.body_entered.is_connected(_on_perception_body_entered):
		_perception.body_entered.connect(_on_perception_body_entered)
	if not _perception.body_exited.is_connected(_on_perception_body_exited):
		_perception.body_exited.connect(_on_perception_body_exited)
	if debug_enabled:
		print("[EnemyBaseV2] Perception connected on", self.name)

func _on_perception_body_entered(body: Node) -> void:
	var as_node2d := body as Node2D
	if as_node2d == null:
		return
	if _is_player(as_node2d):
		_alert_target = as_node2d
		if _state_machine and _state_machine.has_method("transition_to"):
			_state_machine.call("transition_to", &"chase")
			if debug_enabled:
				print("[EnemyBaseV2] Alerted by", as_node2d.name, "-> chase")

func _on_perception_body_exited(body: Node) -> void:
	if body == _alert_target:
		_alert_target = null
		if _state_machine and _state_machine.has_method("transition_to"):
			_state_machine.call("transition_to", &"idle")
			if debug_enabled:
				print("[EnemyBaseV2] Target lost -> idle")

func get_alert_target() -> Node2D:
	return _alert_target

func can_attack_target(target: Node2D) -> bool:
	if target == null:
		return false
	return global_position.distance_to(target.global_position) <= attack_range

func move_toward_position(target_position: Vector2, speed: float) -> void:
	var dir := (target_position - global_position).normalized()
	velocity = dir * speed
	if debug_enabled:
		print("[EnemyBaseV2] move_toward_position", {"target": target_position, "speed": speed, "vel": velocity})

func stop_moving() -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 800.0 * get_physics_process_delta_time())
	if debug_enabled:
		print("[EnemyBaseV2] stop_moving -> vel:", velocity)

## Returns true if an alert target is set
func is_alerted() -> bool:
	return _alert_target != null

## Wrapper for states expecting move_toward(position, speed)
func move_toward(target_position: Vector2, speed: float) -> void:
	move_toward_position(target_position, speed)

## Flip sprite(s) to face a target position along X axis
func flip_sprite_to_face(target_position: Vector2) -> void:
	var face_left := target_position.x < global_position.x
	if _sprite != null:
		_sprite.flip_h = face_left
	if _anim != null:
		_anim.flip_h = face_left
	if debug_enabled:
		print("[EnemyBaseV2] flip_sprite_to_face", {"left": face_left})

func _connect_state_debug() -> void:
	if _state_machine == null:
		return
	if _state_machine.has_signal("state_changed"):
		_state_machine.state_changed.connect(_on_state_changed)
	if _state_machine.has_signal("state_entered"):
		_state_machine.state_entered.connect(_on_state_entered)
	if _state_machine.has_signal("state_exited"):
		_state_machine.state_exited.connect(_on_state_exited)

func _on_state_changed(prev: StringName, curr: StringName) -> void:
	if debug_enabled:
		print("[EnemyBaseV2] State changed:", prev, "->", curr)

func _on_state_entered(curr: StringName) -> void:
	if debug_enabled:
		print("[EnemyBaseV2] State entered:", curr)

func _on_state_exited(prev: StringName) -> void:
	if debug_enabled:
		print("[EnemyBaseV2] State exited:", prev)

func _is_player(body: Node2D) -> bool:
	if body.is_in_group("player"):
		return true
	if body.has_method("player"):
		return true
	return String(body.name) == "Player"

func _connect_health_death() -> void:
	if _health_component and _health_component.has_signal("died"):
		_health_component.died.connect(_on_health_died)

func _on_health_died(source: Node, damage_info: Variant) -> void:
	# Hide the enemy visually
	if _sprite:
		_sprite.visible = false
	if _anim:
		_anim.visible = false
	
	# Disable collision and hurtbox
	if has_node("CollisionShape2D"):
		get_node("CollisionShape2D").disabled = true
	if _hurtbox_component:
		_hurtbox_component.set_enabled(false)
	
	# Stop movement
	velocity = Vector2.ZERO
	
	# Remove from scene after a short delay
	var timer: SceneTreeTimer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): queue_free())



