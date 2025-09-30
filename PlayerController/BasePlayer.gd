extends _PlayerController2D

## BasePlayer extends the reusable PlayerController and wires custom demo behavior.

const AttackStateScript = preload("res://Example_Scenes/CustomState/PlayerStateAttack.gd")
const STATE_ATTACK := StringName("attack")

func _ready() -> void:
	# Initialize PlayerController systems
	super._ready()

	# Register extra demo attack state
	register_additional_state(STATE_ATTACK, AttackStateScript)

	# Optional debug hooks
	player_jumped.connect(_on_player_jumped)
	player_landed.connect(_on_player_landed)
	state_changed.connect(_on_state_changed)

	# Ensure dash action exists with default binding (Shift)
	_ensure_dash_action()

	# Connect attack input via services
	_connect_attack_input()

	# Register Dash ability
	var dash: PlayerAbility = preload("res://PlayerController/abilities/DashAbility.gd").new() as PlayerAbility
	register_ability(StringName("dash"), dash)
	activate_ability(StringName("dash"))

func _ensure_dash_action() -> void:
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		var ev := InputEventKey.new()
		ev.keycode = KEY_SHIFT
		# Also set physical keycode to improve detection on some layouts
		ev.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("dash", ev)
		print("[BasePlayer] Added default dash binding -> SHIFT")
	else:
		var events := InputMap.action_get_events("dash")
		print("[BasePlayer] dash action exists; events:", events)
		if events.is_empty():
			var ev2 := InputEventKey.new()
			ev2.keycode = KEY_SHIFT
			ev2.physical_keycode = KEY_SHIFT
			InputMap.action_add_event("dash", ev2)
			print("[BasePlayer] Added fallback dash binding -> SHIFT")

	# Spawn at current transform
	spawn(global_position)

func _on_player_jumped() -> void:
	print("Player jumped!")

func _on_player_landed() -> void:
	print("Player landed!")

func _on_state_changed(previous: StringName, current: StringName) -> void:
	print("Player state changed from ", previous, " to ", current)

func _connect_attack_input() -> void:
	if InputService and InputService.has_signal("action_event"):
		if not InputService.action_event.is_connected(_on_action_event):
			InputService.action_event.connect(_on_action_event)
	if EventBus and EventBus.has_method("sub"):
		EventBus.call("sub", EventTopics.INPUT_ACTION, Callable(self, "_on_eventbus_action"))

func _on_action_event(action: StringName, edge: String, device: int, event: InputEvent) -> void:
	print("[BasePlayer] _on_action_event: action=", action, " edge=", edge)
	if action == StringName("attack") and edge == "pressed":
		_handle_attack_input()
	elif action == StringName("dash") and edge == "pressed":
		print("[BasePlayer] dash action detected via InputService")
		_handle_dash_input_action(action, edge, device, event)

func _on_eventbus_action(payload: Dictionary) -> void:
	var action: StringName = payload.get("action", StringName(""))
	var edge: String = payload.get("edge", "")
	var device: int = payload.get("device", 0)
	var event: InputEvent = payload.get("event", null)
	print("[BasePlayer] _on_eventbus_action: action=", action, " edge=", edge)
	if action == StringName("attack") and edge == "pressed":
		_handle_attack_input()
	elif action == StringName("dash") and edge == "pressed":
		print("[BasePlayer] dash action detected via EventBus")
		_handle_dash_input_action(action, edge, device, event)


func _handle_attack_input() -> void:
	var current_state = get_current_state()
	if current_state == "idle" or current_state == "move":
		print("Attack input detected! Transitioning to attack state...")
		var result = transition_to_state(STATE_ATTACK, {"attack_type": "basic", "timestamp": Time.get_ticks_msec()})
		if result != OK:
			print("Failed to transition to attack state: ", result)
	else:
		print("Attack ignored - current state is: ", current_state)

func _handle_dash_input_action(action: StringName, edge: String, device: int, event: InputEvent) -> void:
	print("[BasePlayer] _handle_dash_input_action called")
	# Forward to PlayerController's input handling system (call the parent's method directly)
	super._on_action_event(action, edge, device, event)

