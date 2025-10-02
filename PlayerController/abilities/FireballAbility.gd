class_name FireballAbility
extends "res://PlayerController/Ability.gd"

## Fireball ability that shoots a projectile in the direction the player is facing.

@export var fireball_speed: float = 800.0
@export var fireball_damage: float = 25.0
@export var cooldown_duration: float = 2.0
@export var projectile_scene: PackedScene

var _cooldown_timer: float = 0.0
var _can_cast: bool = true

func _on_activated() -> void:
	_reset_state()

func _on_deactivated() -> void:
	_can_cast = false

func on_update(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			_can_cast = true
			emit_debug_log("Fireball ready", "INFO")

func on_input_action(action: StringName, edge: String, _device: int, _event: InputEvent) -> void:
	if action != StringName("fireball") or edge != "pressed":
		return
	if not _can_cast:
		emit_debug_log("Fireball on cooldown", "DEBUG", {"cooldown_remaining": _cooldown_timer})
		return
	_cast_fireball()

func can_cast() -> bool:
	return _can_cast and _cooldown_timer <= 0.0

func _cast_fireball() -> void:
	var controller = get_controller()
	if controller == null:
		emit_debug_log("No controller for fireball", "ERROR")
		return
	
	# Get fireball direction (player facing direction)
	var direction: Vector2 = _get_fireball_direction(controller)
	var spawn_position: Vector2 = controller.global_position + direction * 50.0
	
	# Create fireball projectile
	var fireball = _create_fireball_projectile()
	if fireball == null:
		emit_debug_log("Failed to create fireball projectile", "ERROR")
		return
	
	# Set up fireball
	fireball.global_position = spawn_position
	
	# Add to scene first so script gets applied
	controller.get_tree().current_scene.add_child(fireball)
	
	# Set properties after script is applied
	fireball.direction = direction
	fireball.speed = fireball_speed
	fireball.damage = fireball_damage
	
	# Start cooldown
	_cooldown_timer = cooldown_duration
	_can_cast = false
	
	emit_debug_log("Fireball cast!", "INFO", {
		"direction": direction,
		"position": spawn_position,
		"damage": fireball_damage
	})
	
	# Emit ability used event
	var event_bus: Node = null
	if Engine.has_singleton("EventBus"):
		event_bus = Engine.get_singleton("EventBus")
	emit_lifecycle_event(event_bus, EventTopics.PLAYER_ABILITY_USED, {
		StringName("ability_type"): StringName("fireball"),
		StringName("direction"): direction,
		StringName("damage"): fireball_damage
	})

func _get_fireball_direction(controller: Node) -> Vector2:
	# Get movement input to determine direction
	var input_vector: Vector2 = Vector2.ZERO
	if controller.has_method("get_movement_input"):
		input_vector = controller.get_movement_input()
	
	# If no input, use player's facing direction
	if input_vector.length() < 0.1:
		var scale_x = controller.get("scale").x if controller.has_method("get") else 1.0
		return Vector2(sign(scale_x), 0.0)
	
	return input_vector.normalized()

func _create_fireball_projectile() -> Node:
	# Create fireball using the script file
	var fireball = preload("res://PlayerController/abilities/FireballProjectile.gd").new()
	fireball.name = "Fireball"
	
	# Add colored rectangle instead of sprite
	var color_rect = ColorRect.new()
	color_rect.color = Color.ORANGE
	color_rect.size = Vector2(32, 32)
	color_rect.position = Vector2(-16, -16)  # Center it
	fireball.add_child(color_rect)
	
	# Add collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 16.0
	collision.shape = shape
	fireball.add_child(collision)
	
	# Add area for damage detection
	var area = Area2D.new()
	var area_collision = CollisionShape2D.new()
	area_collision.shape = shape
	area.add_child(area_collision)
	fireball.add_child(area)
	
	return fireball

func serialize_state() -> Dictionary:
	return {
		"cooldown_timer": _cooldown_timer,
		"can_cast": _can_cast
	}

func deserialize_state(data: Dictionary) -> void:
	_cooldown_timer = data.get("cooldown_timer", 0.0)
	_can_cast = data.get("can_cast", true)

func _reset_state() -> void:
	_cooldown_timer = 0.0
	_can_cast = true
