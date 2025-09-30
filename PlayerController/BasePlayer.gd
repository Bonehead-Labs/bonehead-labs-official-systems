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

	# Connect attack input via services
	_connect_attack_input()


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
	else:
		# Forward all other input to parent PlayerController
		super._on_action_event(action, edge, device, event)

func _on_eventbus_action(payload: Dictionary) -> void:
	var action: StringName = payload.get("action", StringName(""))
	var edge: String = payload.get("edge", "")
	var _device: int = payload.get("device", 0)
	var _event: InputEvent = payload.get("event", null)
	print("[BasePlayer] _on_eventbus_action: action=", action, " edge=", edge)
	if action == StringName("attack") and edge == "pressed":
		_handle_attack_input()
	else:
		# Forward all other input to parent PlayerController
		super._on_eventbus_action(payload)


func _handle_attack_input() -> void:
	var current_state = get_current_state()
	if current_state == "idle" or current_state == "move":
		print("Attack input detected! Transitioning to attack state...")
		var result = transition_to_state(STATE_ATTACK, {"attack_type": "basic", "timestamp": Time.get_ticks_msec()})
		if result != OK:
			print("Failed to transition to attack state: ", result)
	else:
		print("Attack ignored - current state is: ", current_state)
