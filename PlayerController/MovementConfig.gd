class_name MovementConfig
extends Resource

## Resource describing movement parameters for a 2D character.

enum MovementMode {
    PLATFORMER,
    TOP_DOWN
}

@export var movement_mode: MovementMode = MovementMode.PLATFORMER
@export var max_speed: float = 220.0
@export var acceleration: float = 1200.0
@export var deceleration: float = 1400.0
@export var air_acceleration: float = 900.0
@export var air_deceleration: float = 1100.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 900.0
@export var max_fall_speed: float = 750.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.08
@export var air_control_multiplier: float = 0.75
@export var allow_jump: bool = true
@export var allow_vertical_input: bool = false
@export var movement_input_deadzone: float = 0.1
@export var interact_action: StringName = StringName("interact")

# Input actions
@export var use_axis_input: bool = false
@export var axis_negative_action: StringName = StringName("move_left")
@export var axis_positive_action: StringName = StringName("move_right")
@export var axis_vertical_negative_action: StringName = StringName("move_up")
@export var axis_vertical_positive_action: StringName = StringName("move_down")
@export var move_left_action: StringName = StringName("move_left")
@export var move_right_action: StringName = StringName("move_right")
@export var move_up_action: StringName = StringName("move_up")
@export var move_down_action: StringName = StringName("move_down")
@export var jump_action: StringName = StringName("jump")

# Optional damping when releasing controls
@export var friction: float = 0.0

func duplicate_config() -> MovementConfig:
    var copy := MovementConfig.new()
    copy.movement_mode = movement_mode
    copy.max_speed = max_speed
    copy.acceleration = acceleration
    copy.deceleration = deceleration
    copy.air_acceleration = air_acceleration
    copy.air_deceleration = air_deceleration
    copy.jump_velocity = jump_velocity
    copy.gravity = gravity
    copy.max_fall_speed = max_fall_speed
    copy.coyote_time = coyote_time
    copy.jump_buffer_time = jump_buffer_time
    copy.air_control_multiplier = air_control_multiplier
    copy.allow_jump = allow_jump
    copy.allow_vertical_input = allow_vertical_input
    copy.movement_input_deadzone = movement_input_deadzone
    copy.interact_action = interact_action
    copy.use_axis_input = use_axis_input
    copy.axis_negative_action = axis_negative_action
    copy.axis_positive_action = axis_positive_action
    copy.axis_vertical_negative_action = axis_vertical_negative_action
    copy.axis_vertical_positive_action = axis_vertical_positive_action
    copy.move_left_action = move_left_action
    copy.move_right_action = move_right_action
    copy.move_up_action = move_up_action
    copy.move_down_action = move_down_action
    copy.jump_action = jump_action
    copy.friction = friction
    return copy
