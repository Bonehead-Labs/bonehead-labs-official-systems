class_name KnockbackResolver
extends Node

## Component that handles knockback physics when entities take damage.
## Applies impulses respecting mass and provides different knockback behaviors.

enum KnockbackMode {
	IMPULSE,        # Single impulse applied instantly
	FORCE,          # Continuous force over time
	VELOCITY_SET,   # Directly set velocity (ignores mass)
	SPRING          # Spring-like bounce effect
}

@export var mode: KnockbackMode = KnockbackMode.IMPULSE
@export var mass_override: float = 0.0  # 0 = use body's mass
@export var max_knockback_speed: float = 1000.0
@export var drag_coefficient: float = 0.1
@export var gravity_multiplier: float = 1.0  # How much gravity affects knockback
@export var air_control_modifier: float = 0.5  # Air control during knockback

# Spring mode parameters
@export var spring_stiffness: float = 500.0
@export var spring_damping: float = 0.8

var _target_body: CharacterBody2D = null
var _is_knockback_active: bool = false
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_duration: float = 0.0
var _elapsed_time: float = 0.0
var _original_gravity: float = 0.0
var _original_air_control: float = 0.0

func _ready() -> void:
	_resolve_target_body()

func _resolve_target_body() -> void:
	_target_body = get_parent() as CharacterBody2D
	if not _target_body:
		push_warning("KnockbackResolver: No CharacterBody2D parent found")

func _physics_process(delta: float) -> void:
	if not _is_knockback_active:
		return

	match mode:
		KnockbackMode.IMPULSE:
			_process_impulse_knockback(delta)
		KnockbackMode.FORCE:
			_process_force_knockback(delta)
		KnockbackMode.VELOCITY_SET:
			_process_velocity_set_knockback(delta)
		KnockbackMode.SPRING:
			_process_spring_knockback(delta)

## Apply knockback to the target
## 
## Applies knockback force to the entity using the configured mode.
## 
## [b]force:[/b] Knockback force vector
## [b]duration:[/b] How long the knockback lasts (default: 0.2 seconds)
## 
## [b]Usage:[/b]
## [codeblock]
## # Apply basic knockback
## knockback_resolver.apply_knockback(Vector2(100, -50), 0.3)
## 
## # Apply knockback from damage
## if damage_info.knockback_force != Vector2.ZERO:
##     knockback_resolver.apply_knockback(damage_info.knockback_force, damage_info.knockback_duration)
## 
## # Apply strong knockback
## knockback_resolver.apply_knockback(Vector2(200, -100), 0.5)
## [/codeblock]
func apply_knockback(force: Vector2, duration: float = 0.2) -> void:
	if not _target_body:
		push_warning("KnockbackResolver: No target body available")
		return

	_is_knockback_active = true
	_knockback_velocity = force
	_knockback_duration = duration
	_elapsed_time = 0.0

	# Store original movement parameters
	if _target_body is CharacterBody2D:
		_original_gravity = _target_body.gravity if "gravity" in _target_body else 0.0
		_original_air_control = 1.0  # Default air control

		# Modify gravity and air control during knockback
		if "gravity" in _target_body:
			_target_body.gravity *= gravity_multiplier

	# Apply initial impulse based on mode
	match mode:
		KnockbackMode.IMPULSE:
			_apply_initial_impulse(force)
		KnockbackMode.VELOCITY_SET:
			_target_body.velocity = force
		KnockbackMode.SPRING:
			_knockback_velocity = force

## Stop knockback immediately
## 
## Immediately stops the current knockback and restores normal movement.
## 
## [b]Usage:[/b]
## [codeblock]
## # Stop knockback early
## knockback_resolver.stop_knockback()
## 
## # Stop knockback on ground contact
## if character.is_on_floor():
##     knockback_resolver.stop_knockback()
## 
## # Stop knockback on death
## func die():
##     knockback_resolver.stop_knockback()
##     # ... death logic
## [/codeblock]
func stop_knockback() -> void:
	_is_knockback_active = false
	_knockback_velocity = Vector2.ZERO
	_elapsed_time = 0.0
	_restore_original_parameters()

## Check if knockback is currently active
## 
## [b]Returns:[/b] true if knockback is active, false otherwise
## 
## [b]Usage:[/b]
## [codeblock]
## if knockback_resolver.is_knockback_active():
##     # Disable movement during knockback
##     character.set_physics_process(false)
## else:
##     # Allow normal movement
##     character.set_physics_process(true)
## 
## # Check for UI feedback
## if knockback_resolver.is_knockback_active():
##     show_knockback_effect()
## [/codeblock]
func is_knockback_active() -> bool:
	return _is_knockback_active

## Get current knockback velocity
## 
## [b]Returns:[/b] Current knockback velocity vector
## 
## [b]Usage:[/b]
## [codeblock]
## var knockback_vel = knockback_resolver.get_knockback_velocity()
## print("Knockback velocity: ", knockback_vel)
## 
## # Use for visual effects
## if knockback_vel.length() > 100:
##     show_strong_knockback_effect()
## [/codeblock]
func get_knockback_velocity() -> Vector2:
	return _knockback_velocity

## Get knockback progress
## 
## Returns how much of the knockback duration has elapsed.
## 
## [b]Returns:[/b] Progress from 0.0 (just started) to 1.0 (completed)
## 
## [b]Usage:[/b]
## [codeblock]
## var progress = knockback_resolver.get_knockback_progress()
## if progress > 0.5:
##     print("Knockback is halfway through")
## 
## # Use for UI progress bars
## knockback_bar.value = progress
## 
## # Fade out effect over time
## effect_alpha = 1.0 - progress
## [/codeblock]
func get_knockback_progress() -> float:
	if _knockback_duration <= 0.0:
		return 1.0
	return min(_elapsed_time / _knockback_duration, 1.0)

## Set knockback mode
## 
## Changes the knockback behavior mode.
## 
## [b]new_mode:[/b] New knockback mode to use
## 
## [b]Usage:[/b]
## [codeblock]
## # Set to impulse mode for instant knockback
## knockback_resolver.set_knockback_mode(KnockbackResolver.KnockbackMode.IMPULSE)
## 
## # Set to spring mode for bouncy knockback
## knockback_resolver.set_knockback_mode(KnockbackResolver.KnockbackMode.SPRING)
## [/codeblock]
func set_knockback_mode(new_mode: KnockbackMode) -> void:
	mode = new_mode

## Set mass override
## 
## Overrides the effective mass for knockback calculations.
## 
## [b]mass:[/b] New mass value (0 = use body's mass)
## 
## [b]Usage:[/b]
## [codeblock]
## # Make entity lighter (more knockback)
## knockback_resolver.set_mass_override(0.5)
## 
## # Make entity heavier (less knockback)
## knockback_resolver.set_mass_override(2.0)
## 
## # Reset to body mass
## knockback_resolver.set_mass_override(0.0)
## [/codeblock]
func set_mass_override(mass: float) -> void:
	mass_override = mass

## Set maximum knockback speed
## 
## Limits the maximum velocity that can be applied during knockback.
## 
## [b]speed:[/b] Maximum speed value
## 
## [b]Usage:[/b]
## [codeblock]
## # Limit knockback speed
## knockback_resolver.set_max_speed(500.0)
## 
## # Allow very fast knockback
## knockback_resolver.set_max_speed(2000.0)
## [/codeblock]
func set_max_speed(speed: float) -> void:
	max_knockback_speed = speed

## Private methods

func _apply_initial_impulse(force: Vector2) -> void:
	var effective_mass = mass_override if mass_override > 0.0 else 1.0
	var impulse = force / effective_mass

	# Clamp to max speed
	if impulse.length() > max_knockback_speed:
		impulse = impulse.normalized() * max_knockback_speed

	_target_body.velocity += impulse

func _process_impulse_knockback(delta: float) -> void:
	_elapsed_time += delta

	# Apply drag to slow down over time
	var drag_force = -_target_body.velocity * drag_coefficient
	_target_body.velocity += drag_force * delta

	# Check if knockback should end
	if _elapsed_time >= _knockback_duration or _target_body.velocity.length() < 50.0:
		stop_knockback()

func _process_force_knockback(delta: float) -> void:
	_elapsed_time += delta

	# Apply continuous force
	var effective_mass = mass_override if mass_override > 0.0 else 1.0
	var force = _knockback_velocity / effective_mass
	_target_body.velocity += force * delta

	# Apply drag
	var drag_force = -_target_body.velocity * drag_coefficient
	_target_body.velocity += drag_force * delta

	# Check if knockback should end
	if _elapsed_time >= _knockback_duration:
		stop_knockback()

func _process_velocity_set_knockback(delta: float) -> void:
	_elapsed_time += delta

	# Directly set velocity with decay
	var decay_factor = 1.0 - (_elapsed_time / _knockback_duration)
	decay_factor = max(decay_factor, 0.0)

	var current_velocity = _knockback_velocity * decay_factor
	current_velocity.x *= (1.0 - air_control_modifier)  # Allow some air control

	_target_body.velocity.x = current_velocity.x
	_target_body.velocity.y = current_velocity.y

	# Check if knockback should end
	if _elapsed_time >= _knockback_duration:
		stop_knockback()

func _process_spring_knockback(delta: float) -> void:
	_elapsed_time += delta

	# Spring-like behavior
	var displacement = _target_body.velocity - _knockback_velocity
	var spring_force = -displacement * spring_stiffness
	var damping_force = -_target_body.velocity * spring_damping

	_target_body.velocity += (spring_force + damping_force) * delta

	# Check if knockback should end
	if _elapsed_time >= _knockback_duration or _target_body.velocity.length() < 10.0:
		stop_knockback()

func _restore_original_parameters() -> void:
	# Restore original movement parameters
	if _target_body and "gravity" in _target_body:
		_target_body.gravity = _original_gravity
