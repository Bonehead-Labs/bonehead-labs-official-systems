class_name Steering
extends RefCounted

static func seek(current_velocity: Vector2, current_position: Vector2, target_position: Vector2, max_speed: float, accel: float, dt: float) -> Vector2:
    var desired := (target_position - current_position).normalized() * max_speed
    return current_velocity.move_toward(desired, accel * dt)

static func flee(current_velocity: Vector2, current_position: Vector2, target_position: Vector2, max_speed: float, accel: float, dt: float) -> Vector2:
    var desired := (current_position - target_position).normalized() * max_speed
    return current_velocity.move_toward(desired, accel * dt)

static func wander(current_velocity: Vector2, max_speed: float, accel: float, dt: float, jitter: float = 0.1) -> Vector2:
    var jitter_vec := Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))
    var desired := (current_velocity + jitter_vec).limit_length(max_speed)
    return current_velocity.move_toward(desired, accel * dt)

