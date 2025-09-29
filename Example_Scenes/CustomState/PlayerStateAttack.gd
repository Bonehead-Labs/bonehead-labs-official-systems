extends "res://PlayerController/states/PlayerMovementState.gd"

## Attack state for the player controller
## Handles attack animations, hit detection, and attack cooldowns
## This is an example implementation showing how to add custom states

var attack_duration: float = 0.8
var attack_timer: float = 0.0
var can_attack: bool = true
var original_modulate: Color
var original_scale: Vector2

func enter(payload: Dictionary[StringName, Variant] = {}) -> void:
	emit_state_entered(StringName("attack"), payload)
	
	# Reset attack timer
	attack_timer = attack_duration
	can_attack = false
	
	# Store original visual properties for restoration
	if controller:
		original_modulate = controller.modulate
		original_scale = controller.scale
		
		# Visual feedback: Change color to red and scale up slightly
		controller.modulate = Color.RED
		controller.scale = Vector2(1.2, 1.2)
		
		# Play random hit sound effect
		_play_attack_sound()
		
		# Print debug info
		print("Player started attacking! Duration: ", attack_duration, " seconds")

func exit(payload: Dictionary[StringName, Variant] = {}) -> void:
	emit_state_exited(StringName("attack"), payload)
	
	# Restore original visual properties
	if controller:
		controller.modulate = original_modulate
		controller.scale = original_scale
		
		# Print debug info
		print("Player finished attacking!")

func update(delta: float) -> void:
	# Update attack timer
	attack_timer -= delta
	
	# Visual feedback: Pulsing effect during attack
	if controller:
		var pulse_intensity = sin(attack_timer * 20.0) * 0.1 + 1.0
		controller.scale = Vector2(1.2, 1.2) * pulse_intensity
	
	# Check if attack is finished
	if attack_timer <= 0.0:
		# Determine next state based on input
		var input_vector := get_input_vector()
		if input_vector.length_squared() > 0.0:
			safe_transition_to(StringName("move"), {}, StringName("attack_finished_with_movement"))
		else:
			safe_transition_to(StringName("idle"), {}, StringName("attack_finished"))
		return

func physics_update(delta: float) -> void:
	if controller == null or movement_config == null:
		return
	
	# During attack, player can still move but with reduced speed
	var input_vector := get_input_vector()
	if is_platformer():
		# In platformer mode, allow limited horizontal movement during attack
		controller.move_platformer_horizontal(input_vector.x * 0.4, delta, false)
		if not controller.is_on_floor():
			controller.apply_gravity(delta)
	else:
		# In top-down mode, allow limited movement in all directions
		controller.move_top_down(input_vector * 0.4, delta)

func can_transition_to(state: StringName) -> bool:
	# Can only transition to idle or move states from attack
	match state:
		"idle", "move":
			return true
		"jump", "fall":
			# Only allow if in platformer mode and attack is finished
			return is_platformer() and attack_timer <= 0.0
		_:
			return false

func handle_event(event: StringName, _data: Variant = null) -> void:
	match event:
		"attack_requested":
			# Ignore attack requests while already attacking
			print("Attack ignored - already attacking!")
		"jump_requested":
			# Only allow jumping if attack is finished
			if attack_timer <= 0.0:
				safe_transition_to(StringName("jump"), {}, StringName("jump_during_attack"))
			else:
				print("Jump ignored - still attacking!")

## Get remaining attack time
## 
## Returns the remaining time in the attack state.
## Useful for UI elements or other systems that need to know attack progress.
## 
## [b]Returns:[/b] Remaining attack time in seconds
func get_remaining_attack_time() -> float:
	return max(0.0, attack_timer)

## Check if currently attacking
## 
## Returns whether the player is currently in an attack state.
## 
## [b]Returns:[/b] true if attacking, false otherwise
func is_attacking() -> bool:
	return attack_timer > 0.0

## Play a random hit sound effect when attacking
func _play_attack_sound() -> void:
	# Find LevelDemo in the scene (which now handles audio)
	var level_demo = _find_level_demo()
	if level_demo != null and level_demo.has_method("play_random_hit"):
		level_demo.play_random_hit()
		print("PlayerStateAttack: Played attack sound")
	else:
		print("PlayerStateAttack: No LevelDemo found for attack sound")

## Find LevelDemo in the scene
func _find_level_demo() -> Node:
	# Look for LevelDemo in the scene tree
	var root = Engine.get_main_loop().current_scene
	if root != null:
		return _find_node_by_class(root, LevelDemo)
	
	return null

## Recursively find a node of a specific class
func _find_node_by_class(node: Node, target_class: GDScript) -> Node:
	if node.get_script() == target_class:
		return node
	
	for child in node.get_children():
		var result = _find_node_by_class(child, target_class)
		if result != null:
			return result
	
	return null
