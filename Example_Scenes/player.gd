extends _PlayerController2D

## Player character using the PlayerController system for platformer movement
## This demonstrates how to integrate the bonehead-labs systems into a game
## The PlayerController is now the main CharacterBody2D node

# Attack state script and constant
const AttackStateScript = preload("res://Example_Scenes/PlayerStateAttack.gd")
const STATE_ATTACK := StringName("attack")

func _ready() -> void:
	# Optional code based movement config.
	#_setup_movement_config()
	
	# Call parent's _ready() to initialize the PlayerController system
	super._ready()
	
	# Register the attack state
	register_additional_state(STATE_ATTACK, AttackStateScript)
	
	# Debug: Check if state machine is working
	print("Player ready - State machine: ", _state_machine)
	print("Player ready - Movement config: ", movement_config)
	print("Player ready - Current state: ", get_current_state())
	
	# Debug: Check available states
	if _state_machine:
		print("Player ready - Has idle state: ", _state_machine.has_state("idle"))
		print("Player ready - Has move state: ", _state_machine.has_state("move"))
		print("Player ready - Has jump state: ", _state_machine.has_state("jump"))
		print("Player ready - Has fall state: ", _state_machine.has_state("fall"))
		print("Player ready - Has attack state: ", _state_machine.has_state("attack"))
	
	# Connect to player controller signals for debugging/effects
	player_jumped.connect(_on_player_jumped)
	player_landed.connect(_on_player_landed)
	state_changed.connect(_on_state_changed)
	
	# Connect to input events for attack
	_connect_attack_input()
	
	# Spawn the player at current position
	spawn(global_position)

func _on_player_jumped() -> void:
	print("Player jumped!")

func _on_player_landed() -> void:
	print("Player landed!")

func _on_state_changed(previous: StringName, current: StringName) -> void:
	print("Player state changed from ", previous, " to ", current)

## Connect to input events for attack functionality
func _connect_attack_input() -> void:
	# Connect to InputService if available
	if InputService and InputService.has_signal("action_event"):
		if not InputService.action_event.is_connected(_on_action_event):
			InputService.action_event.connect(_on_action_event)
	
	# Also connect to EventBus input events as fallback
	if EventBus and EventBus.has_method("sub"):
		EventBus.call("sub", EventTopics.INPUT_ACTION, Callable(self, "_on_eventbus_action"))

## Handle action events from InputService
func _on_action_event(action: StringName, edge: String, _device: int, _event: InputEvent) -> void:
	if action == StringName("attack") and edge == "pressed":
		_handle_attack_input()

## Handle action events from EventBus
func _on_eventbus_action(payload: Dictionary) -> void:
	var action: StringName = payload.get("action", StringName(""))
	var edge: String = payload.get("edge", "")
	
	if action == StringName("attack") and edge == "pressed":
		_handle_attack_input()

## Handle attack input and transition to attack state
func _handle_attack_input() -> void:
	var current_state = get_current_state()
	
	# Only allow attack from idle or move states
	if current_state == "idle" or current_state == "move":
		print("Attack input detected! Transitioning to attack state...")
		var result = transition_to_state(STATE_ATTACK, {"attack_type": "basic", "timestamp": Time.get_ticks_msec()})
		if result != OK:
			print("Failed to transition to attack state: ", result)
	else:
		print("Attack ignored - current state is: ", current_state)

func _physics_process(delta: float) -> void:
	# Call parent's physics process
	super._physics_process(delta)
	
	# # Debug: Print velocity and position occasionally
	# if Engine.get_process_frames() % 60 == 0:  # Every second
	# 	print("Player physics - Position: ", global_position, " Velocity: ", velocity)
	# 	print("Player physics - State: ", get_current_state())
	# 	print("Player physics - Input: ", get_movement_input())
	# 	print("Player physics - On floor: ", is_on_floor())
	# 	print("Player physics - InputService connected: ", _input_service_connected)
	# 	print("Player physics - Axis values: ", _axis_values)



##----Code based movement config (Alternative to using the MovementConfig.tres file)----
func _setup_movement_config() -> void:
	# Create and configure movement settings for platformer
	movement_config = MovementConfig.new()
	movement_config.movement_mode = MovementConfig.MovementMode.PLATFORMER
	movement_config.max_speed = 220.0
	movement_config.acceleration = 1200.0
	movement_config.deceleration = 1400.0
	movement_config.air_acceleration = 900.0
	movement_config.air_deceleration = 1100.0
	movement_config.jump_velocity = -420.0
	movement_config.gravity = 900.0
	movement_config.max_fall_speed = 750.0
	movement_config.coyote_time = 0.1
	movement_config.jump_buffer_time = 0.08
	movement_config.air_control_multiplier = 0.75
	movement_config.allow_jump = true
	movement_config.allow_vertical_input = false
	movement_config.movement_input_deadzone = 0.1
	movement_config.interact_action = StringName("interact")
	movement_config.use_axis_input = false
	movement_config.axis_negative_action = StringName("move_left")
	movement_config.axis_positive_action = StringName("move_right")
	movement_config.axis_vertical_negative_action = StringName("move_up")
	movement_config.axis_vertical_positive_action = StringName("move_down")
	movement_config.move_left_action = StringName("move_left")
	movement_config.move_right_action = StringName("move_right")
	movement_config.move_up_action = StringName("move_up")
	movement_config.move_down_action = StringName("move_down")
	movement_config.jump_action = StringName("jump")
	movement_config.friction = 0.0