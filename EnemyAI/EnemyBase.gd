class_name EnemyBase
extends CharacterBody2D

## Base class for 2D enemies leveraging the shared FSM system.
## Provides common functionality for movement, combat, and AI behavior.

const EnemyConfigScript = preload("res://EnemyAI/EnemyConfig.gd")
const StateMachineScript = preload("res://systems/fsm/StateMachine.gd")
const HealthComponentScript = preload("res://Combat/HealthComponent.gd")
const HurtboxComponentScript = preload("res://Combat/HurtboxComponent.gd")
const HitboxComponentScript = preload("res://Combat/HitboxComponent.gd")
const DeathHandlerScript = preload("res://Combat/DeathHandler.gd")
const DamageInfoScript = preload("res://Combat/DamageInfo.gd")

signal spawned(enemy: EnemyBase, spawn_position: Vector2)
signal alerted(enemy: EnemyBase, alert_target: Node2D)
signal defeated(enemy: EnemyBase, defeat_cause: String)
signal state_changed(enemy: EnemyBase, old_state: StringName, new_state: StringName)

@export var config: EnemyConfigScript
@export var initial_state: StringName = &"patrol"

# Core components
var _state_machine: StateMachineScript
var _health_component: HealthComponentScript
var _hurtbox_component: HurtboxComponentScript
var _hitbox_component: HitboxComponentScript
var _death_handler: DeathHandlerScript

# State tracking
var _current_state: StringName = &""
var _alert_target: Node2D = null
var _alert_timer: float = 0.0
var _is_defeated: bool = false

# Movement
var _velocity: Vector2 = Vector2.ZERO
var _facing_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
    _setup_components()
    _setup_state_machine()
    _setup_visuals()
    _connect_signals()

    # Emit spawn event
    spawned.emit(self, global_position)

    if config and config.emit_analytics:
        _emit_analytics_event("spawned", {
            "position": global_position,
            "config": config.analytics_category if config else "unknown"
        })

func _setup_components() -> void:
    # Health component
    _health_component = HealthComponentScript.new()
    if config:
        _health_component.max_health = config.max_health
    _health_component.auto_register_with_save_service = false
    add_child(_health_component)

    # Hurtbox component
    _hurtbox_component = HurtboxComponentScript.new()
    if config:
        _hurtbox_component.faction = config.faction
        _hurtbox_component.friendly_fire = config.friendly_fire
    _hurtbox_component.health_component_path = _health_component.get_path()
    add_child(_hurtbox_component)

    # Hitbox component (optional - some enemies might not deal contact damage)
    if has_node("HitboxComponent"):
        _hitbox_component = get_node("HitboxComponent") as HitboxComponentScript
        if config:
            _hitbox_component.faction = config.faction
    else:
        _hitbox_component = HitboxComponentScript.new()
        if config:
            _hitbox_component.faction = config.faction
        add_child(_hitbox_component)

    # Death handler
    _death_handler = DeathHandlerScript.new()
    if config:
        _death_handler.respawn_enabled = false  # Enemies typically don't respawn
        _death_handler.emit_analytics = config.emit_analytics
        _death_handler.death_animation_duration = config.death_animation_duration
    add_child(_death_handler)

func _setup_state_machine() -> void:
    _state_machine = StateMachineScript.new()
    _state_machine.initial_state = initial_state

    # Set up context for states
    var context = {
        &"enemy": self,
        &"config": config,
        &"health_component": _health_component,
        &"hurtbox_component": _hurtbox_component,
        &"hitbox_component": _hitbox_component
    }
    _state_machine.set_context(context)

    add_child(_state_machine)

    # Connect to state machine signals
    _state_machine.state_changed.connect(_on_state_changed)

func _setup_visuals() -> void:
    # Apply visual configuration
    if config:
        scale = config.sprite_scale

    # Ensure required collision shape exists
    if not has_node("CollisionShape2D"):
        push_error("EnemyBase: Missing required CollisionShape2D node")
        var collision = CollisionShape2D.new()
        var shape = RectangleShape2D.new()
        shape.size = Vector2(32, 32)
        collision.shape = shape
        add_child(collision)

    # Ensure required AnimatedSprite2D exists
    if not has_node("AnimatedSprite2D"):
        push_warning("EnemyBase: Missing recommended AnimatedSprite2D node")
        var sprite = AnimatedSprite2D.new()
        add_child(sprite)

func _connect_signals() -> void:
    # Health signals
    if _health_component:
        _health_component.died.connect(_on_died)

    # Alert system
    if has_node("PerceptionArea"):
        var perception = get_node("PerceptionArea")
        perception.body_entered.connect(_on_body_detected)
        perception.body_exited.connect(_on_body_lost)

func _physics_process(delta: float) -> void:
    if _is_defeated:
        return

    # Update state machine
    _state_machine.physics_update_state(delta)

    # Update alert timer
    if _alert_target and _alert_timer > 0:
        _alert_timer -= delta
        if _alert_timer <= 0:
            _lose_alert()

    # Apply movement
    velocity = _velocity
    move_and_slide()

    # Update facing direction based on movement
    if _velocity.x != 0:
        _facing_direction = Vector2(sign(_velocity.x), 0)

func _on_state_changed(old_state: StringName, new_state: StringName) -> void:
    _current_state = new_state
    state_changed.emit(self, old_state, new_state)

    if config and config.emit_analytics:
        _emit_analytics_event("state_changed", {
            "old_state": old_state,
            "new_state": new_state
        })

## Alert system
func alert(target: Node2D) -> void:
    if _alert_target != target:
        _alert_target = target
        _alert_timer = config.alert_duration if config else 10.0
        alerted.emit(self, target)

        if config and config.emit_analytics:
            _emit_analytics_event("alerted", {
                "target": String(target.name) if target else "unknown",
                "position": global_position
            })

func _lose_alert() -> void:
    _alert_target = null
    _alert_timer = 0.0

func is_alerted() -> bool:
    return _alert_target != null

func get_alert_target() -> Node2D:
    return _alert_target

## Movement helpers
func move_toward(target_position: Vector2, speed: float = -1.0) -> void:
    if speed < 0:
        speed = config.movement_speed if config else 100.0

    var direction = (target_position - global_position).normalized()
    _velocity = _velocity.move_toward(direction * speed, (config.acceleration if config else 800.0) * get_physics_process_delta_time())

func stop_moving() -> void:
    _velocity = _velocity.move_toward(Vector2.ZERO, (config.friction if config else 600.0) * get_physics_process_delta_time())

func jump() -> void:
    if config and config.can_jump and is_on_floor():
        _velocity.y = -(config.jump_force)

func get_facing_direction() -> Vector2:
    return _facing_direction

## Combat helpers
func attack(target: Node2D = null) -> void:
    if target == null:
        target = _alert_target

    if target and _hitbox_component:
        _hitbox_component.activate()
        # States should handle the actual attack logic

func can_attack_target(target: Node2D) -> bool:
    if not target:
        return false

    var distance = global_position.distance_to(target.global_position)
    var max_range = config.attack_range if config else 50.0

    return distance <= max_range

func take_damage(amount: float, source: Node = null, _damage_type: String = "physical") -> void:
    if _health_component:
        var damage_info = preload("res://Combat/DamageInfo.gd").create_damage(amount, DamageInfoScript.DamageType.PHYSICAL, source)
        _health_component.take_damage(damage_info)

## Death handling
func _on_died(_source: Node, damage_info: Variant) -> void:
    _is_defeated = true
    defeated.emit(self, "damage")

    if config and config.emit_analytics:
        _emit_analytics_event("defeated", {
            "cause": "damage",
            "damage_source": damage_info.source_name if damage_info and damage_info.has("source_name") else "unknown",
            "final_health": 0,
            "position": global_position
        })

func die() -> void:
    if not _is_defeated and _health_component:
        _health_component.kill()

## Perception system
func _on_body_detected(body: Node2D) -> void:
    # Check if body should trigger alert (player, etc.)
    if _should_alert_to_body(body):
        alert(body)

func _on_body_lost(body: Node2D) -> void:
    if body == _alert_target:
        # Body left perception range, but stay alert for a while
        pass  # Timer will handle losing alert

func _should_alert_to_body(body: Node2D) -> bool:
    # Override in subclasses to define what triggers alerts
    # Default: alert to anything with "player" group
    return body.is_in_group("player")

## Animation helpers
func play_animation(animation: String, speed: float = 1.0) -> void:
    var sprite = get_node_or_null("AnimatedSprite2D")
    if sprite and sprite.sprite_frames:
        sprite.speed_scale = speed * (config.animation_speed if config else 1.0)
        sprite.play(animation)

func flip_sprite_to_face(target_position: Vector2) -> void:
    var sprite = get_node_or_null("AnimatedSprite2D")
    if sprite:
        sprite.flip_h = target_position.x < global_position.x

## Analytics
func _emit_analytics_event(event_type: String, data: Dictionary) -> void:
    if not Engine.has_singleton("EventBus"):
        return

    var payload = data.duplicate()
    payload["enemy_type"] = get_class()
    payload["enemy_name"] = name
    payload["faction"] = config.faction if config else "unknown"
    payload["current_state"] = _current_state
    payload["timestamp_ms"] = Time.get_ticks_msec()

    Engine.get_singleton("EventBus").call("pub", &"enemy/" + event_type, payload)

## Save/Load integration (basic)
func save_data() -> Dictionary:
    var health_data = {}
    if _health_component:
        health_data = _health_component.save_data()

    return {
        "global_position": { "x": global_position.x, "y": global_position.y },
        "velocity": { "x": _velocity.x, "y": _velocity.y },
        "facing_direction": { "x": _facing_direction.x, "y": _facing_direction.y },
        "current_state": _current_state,
        "is_alerted": is_alerted(),
        "alert_timer": _alert_timer,
        "health_data": health_data
    }

func load_data(data: Dictionary) -> bool:
    global_position = Vector2(data.get("global_position", {}).get("x", 0.0), data.get("global_position", {}).get("y", 0.0))
    _velocity = Vector2(data.get("velocity", {}).get("x", 0.0), data.get("velocity", {}).get("y", 0.0))
    _facing_direction = Vector2(data.get("facing_direction", {}).get("x", 1.0), data.get("facing_direction", {}).get("y", 0.0))

    var target_state = data.get("current_state", initial_state)
    if target_state != StringName():
        _state_machine.transition_to(target_state)

    if data.get("is_alerted", false):
        _alert_timer = data.get("alert_timer", 0.0)

    var health_data = data.get("health_data", {})
    if _health_component and not health_data.is_empty():
        _health_component.load_data(health_data)

    return true

## Getters for state access
func get_current_state() -> StringName:
    return _current_state

func get_health_component() -> HealthComponentScript:
    return _health_component

func get_hurtbox_component() -> HurtboxComponentScript:
    return _hurtbox_component

func get_hitbox_component() -> HitboxComponentScript:
    return _hitbox_component

func get_state_machine() -> StateMachineScript:
    return _state_machine

func get_config() -> EnemyConfigScript:
    return config
