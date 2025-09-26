class_name BaseProjectile
extends CharacterBody2D

## Base projectile class with configurable motion, lifetime, and damage.
## Designed for object pooling and extensible behavior through inheritance.

const EventTopics = preload("res://EventBus/EventTopics.gd")
const DamageInfoScript = preload("res://Combat/DamageInfo.gd")

enum MotionType {
	LINEAR,         # Straight line movement
	HOMING,         # Homes in on target
	ARC,           # Parabolic arc
	WAVE,          # Sinusoidal wave motion
	BOUNCE,        # Bounces off surfaces
	SPIRAL         # Spiral motion
}

@export var motion_type: MotionType = MotionType.LINEAR
@export var speed: float = 300.0
@export var lifetime: float = 5.0
@export var damage_amount: float = 10.0
@export var damage_type: DamageInfoScript.DamageType = DamageInfoScript.DamageType.PHYSICAL
@export var faction: String = "neutral"
@export var pierce_count: int = 0  # How many enemies it can hit (-1 = infinite)
@export var knockback_force: Vector2 = Vector2.ZERO

# Motion-specific parameters
@export var homing_strength: float = 1.0  # For HOMING motion
@export var arc_height: float = 50.0     # For ARC motion
@export var wave_frequency: float = 2.0  # For WAVE motion
@export var wave_amplitude: float = 20.0 # For WAVE motion
@export var bounce_count: int = 3        # For BOUNCE motion
@export var spiral_speed: float = 2.0    # For SPIRAL motion

# Visual effects
@export var trail_effect: PackedScene
@export var impact_effect: PackedScene

var _target: Node2D = null
var _start_position: Vector2
var _start_velocity: Vector2
var _time_alive: float = 0.0
var _pierce_remaining: int
var _bounces_remaining: int
var _is_destroyed: bool = false

func _ready() -> void:
	_start_position = global_position
	_pierce_remaining = pierce_count
	_bounces_remaining = bounce_count

	# Initialize motion
	_initialize_motion()

	# Set up hitbox
	_setup_hitbox()

func _initialize_motion() -> void:
	match motion_type:
		MotionType.LINEAR:
			velocity = _start_velocity.normalized() * speed
		MotionType.HOMING:
			velocity = _start_velocity.normalized() * speed
		MotionType.ARC:
			velocity = _start_velocity.normalized() * speed
		MotionType.WAVE:
			velocity = _start_velocity.normalized() * speed
		MotionType.BOUNCE:
			velocity = _start_velocity.normalized() * speed
		MotionType.SPIRAL:
			velocity = _start_velocity.normalized() * speed

func _setup_hitbox() -> void:
	var hitbox = get_node_or_null("HitboxComponent")
	if hitbox and hitbox.has_method("set_damage"):
		hitbox.set_damage(damage_amount, damage_type)
		hitbox.faction = faction
		hitbox.knockback_force = knockback_force

func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return

	_time_alive += delta

	# Check lifetime
	if _time_alive >= lifetime:
		destroy()
		return

	# Update motion
	_update_motion(delta)

	# Move
	var collision = move_and_slide()

	# Handle collisions
	if collision:
		_handle_collision(collision)

func _update_motion(delta: float) -> void:
	match motion_type:
		MotionType.LINEAR:
			# Straight line - no change needed
			pass
		MotionType.HOMING:
			_update_homing_motion(delta)
		MotionType.ARC:
			_update_arc_motion(delta)
		MotionType.WAVE:
			_update_wave_motion(delta)
		MotionType.SPIRAL:
			_update_spiral_motion(delta)

func _update_homing_motion(delta: float) -> void:
	if _target:
		var direction_to_target = (_target.global_position - global_position).normalized()
		var current_direction = velocity.normalized()
		var new_direction = current_direction.lerp(direction_to_target, homing_strength * delta)
		velocity = new_direction * speed

func _update_arc_motion(_delta: float) -> void:
	# Calculate parabolic arc
	var progress = _time_alive / lifetime
	var arc_offset = sin(progress * PI) * arc_height
	global_position.y = _start_position.y - arc_offset

func _update_wave_motion(delta: float) -> void:
	var wave_offset = sin(_time_alive * wave_frequency) * wave_amplitude
	var perpendicular = Vector2(-velocity.y, velocity.x).normalized()
	global_position += perpendicular * wave_offset * delta

func _update_spiral_motion(_delta: float) -> void:
	var angle = _time_alive * spiral_speed
	var radius = speed * _time_alive * 0.1
	var spiral_pos = Vector2(cos(angle), sin(angle)) * radius
	global_position = _start_position + spiral_pos

func _handle_collision(collision: KinematicCollision2D) -> void:
	match motion_type:
		MotionType.BOUNCE:
			if _bounces_remaining > 0:
				velocity = velocity.bounce(collision.get_normal())
				_bounces_remaining -= 1
			else:
				destroy()
		_:
			# Default behavior - destroy on collision
			destroy()

## Launch the projectile
## 
## Initializes the projectile with direction, speed, and optional target.
## 
## [b]direction:[/b] Direction vector for the projectile
## [b]start_speed:[/b] Initial speed (-1 to use default speed)
## [b]target:[/b] Target node for homing projectiles (optional)
## 
## [b]Usage:[/b]
## [codeblock]
## # Launch projectile in direction
## projectile.launch(Vector2(1, 0), 500.0)
## 
## # Launch homing projectile
## projectile.launch(Vector2(1, 0), 300.0, enemy)
## 
## # Launch with default speed
## projectile.launch(Vector2(0, -1))
## [/codeblock]
func launch(direction: Vector2, start_speed: float = -1.0, target: Node2D = null) -> void:
	if start_speed > 0.0:
		speed = start_speed

	_start_velocity = direction.normalized() * speed
	_target = target

	_initialize_motion()

	# Emit analytics
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").call("pub", EventTopics.COMBAT_PROJECTILE_FIRED, {
			"projectile_type": get_class(),
			"faction": faction,
			"damage_amount": damage_amount,
			"damage_type": DamageInfoScript.DamageType.keys()[damage_type],
			"position": global_position,
			"velocity": velocity,
			"target": _target.name if _target else StringName("none"),
			"timestamp_ms": Time.get_ticks_msec()
		})

## Handle projectile hit
## 
## Called when the projectile hits a target. Handles pierce mechanics,
## impact effects, and destruction logic.
## 
## [b]hit_target:[/b] Node that was hit
## 
## [b]Usage:[/b] Called automatically by hitbox collision detection
func on_hit(hit_target: Node) -> void:
	_pierce_remaining -= 1

	# Create impact effect
	if impact_effect:
		var effect: Node = impact_effect.instantiate()
		get_parent().add_child(effect)
		effect.global_position = global_position

	# Emit analytics
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").call("pub", EventTopics.COMBAT_PROJECTILE_HIT, {
			"projectile_type": get_class(),
			"target_type": hit_target.get_class(),
			"faction": faction,
			"damage_amount": damage_amount,
			"position": global_position,
			"pierce_remaining": _pierce_remaining,
			"timestamp_ms": Time.get_ticks_msec()
		})

	# Check if projectile should be destroyed
	if _pierce_remaining < 0:
		destroy()

## Destroy the projectile
## 
## Destroys the projectile and creates final impact effects.
## 
## [b]Usage:[/b] Called automatically when lifetime expires or pierce count reached
func destroy() -> void:
	if _is_destroyed:
		return

	_is_destroyed = true

	# Create final impact effect
	if impact_effect:
		var effect: Node = impact_effect.instantiate()
		get_parent().add_child(effect)
		effect.global_position = global_position

	# Return to pool or queue free
	queue_free()

## Set projectile damage
## 
## Updates the damage amount and type for this projectile.
## 
## [b]amount:[/b] New damage amount
## [b]type:[/b] New damage type (default: current type)
## 
## [b]Usage:[/b]
## [codeblock]
## # Set basic damage
## projectile.set_damage(25.0)
## 
## # Set damage with type
## projectile.set_damage(30.0, DamageInfo.DamageType.FIRE)
## 
## # Upgrade projectile damage
## projectile.set_damage(projectile.damage_amount * 1.5)
## [/codeblock]
func set_damage(amount: float, type: DamageInfoScript.DamageType = damage_type) -> void:
	damage_amount = amount
	damage_type = type

	var hitbox: Node = get_node_or_null("HitboxComponent")
	if hitbox and hitbox.has_method("set_damage"):
		hitbox.set_damage(amount, type)

## Set projectile knockback
## 
## Updates the knockback force for this projectile.
## 
## [b]force:[/b] New knockback force vector
## 
## [b]Usage:[/b]
## [codeblock]
## # Set knockback
## projectile.set_knockback(Vector2(100, -50))
## 
## # Remove knockback
## projectile.set_knockback(Vector2.ZERO)
## 
## # Increase knockback
## projectile.set_knockback(projectile.knockback_force * 1.5)
## [/codeblock]
func set_knockback(force: Vector2) -> void:
	knockback_force = force
	var hitbox: Node = get_node_or_null("HitboxComponent")
	if hitbox:
		hitbox.knockback_force = force

## Set projectile faction
## 
## Updates the faction for this projectile.
## 
## [b]new_faction:[/b] New faction name
## 
## [b]Usage:[/b]
## [codeblock]
## # Set faction
## projectile.set_faction("player")
## 
## # Set enemy faction
## projectile.set_faction("enemy")
## 
## # Copy faction from source
## projectile.set_faction(source_entity.faction)
## [/codeblock]
func set_faction(new_faction: String) -> void:
	faction = new_faction
	var hitbox: Node = get_node_or_null("HitboxComponent")
	if hitbox:
		hitbox.faction = new_faction

## Get projectile damage info
## 
## Creates a DamageInfo instance for this projectile.
## 
## [b]Returns:[/b] DamageInfo instance with projectile parameters
## 
## [b]Usage:[/b]
## [codeblock]
## # Get damage info for custom damage dealing
## var damage_info = projectile.get_damage_info()
## target.take_damage(damage_info)
## 
## # Modify damage before applying
## var damage_info = projectile.get_damage_info()
## damage_info.amount *= 1.5  # 50% more damage
## [/codeblock]
func get_damage_info() -> Variant:
	return DamageInfoScript.create_damage(damage_amount, damage_type, self)

## Get time projectile has been alive
## 
## [b]Returns:[/b] Time in seconds since launch
## 
## [b]Usage:[/b]
## [codeblock]
## var age = projectile.get_time_alive()
## if age > 2.0:
##     print("Projectile is getting old")
## 
## # Use for visual effects
## var alpha = 1.0 - (age / projectile.lifetime)
## projectile.modulate.a = alpha
## [/codeblock]
func get_time_alive() -> float:
	return _time_alive

## Get distance projectile has traveled
## 
## [b]Returns:[/b] Distance in pixels from start position
## 
## [b]Usage:[/b]
## [codeblock]
## var distance = projectile.get_distance_traveled()
## print("Projectile traveled ", distance, " pixels")
## 
## # Use for range calculations
## if distance > max_range:
##     projectile.destroy()
## [/codeblock]
func get_distance_traveled() -> float:
	return global_position.distance_to(_start_position)
