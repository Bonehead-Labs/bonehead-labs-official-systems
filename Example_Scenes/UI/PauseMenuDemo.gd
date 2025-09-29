class_name PauseMenuDemo
extends Control

## Pause menu demo using DialogTemplate with Resume and Settings options.
## This demonstrates how to create a pause menu using the UI template system.

const DIALOG_TEMPLATE: PackedScene = preload("res://UI/Templates/DialogTemplate.tscn")
const SETTINGS_TEMPLATE: PackedScene = preload("res://UI/Templates/SettingsTemplate.tscn")

var _pause_dialog: _UITemplate
var _settings_dialog: _UITemplate
var _is_paused: bool = false
var _game_scene: Node
var _dialog_host: CenterContainer
var _ui_layer: CanvasLayer
var _overlay: Control

# Volume mapping for sliders (0..1) <-> decibels using perceptual mapping
const VOL_DB_MIN: float = -60.0
const VOL_DB_MAX: float = 0.0

func _ready() -> void:
	# Set process mode to continue processing when paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# Ensure this Control fills the viewport so child dialogs have space
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Don't intercept mouse input when not visible
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create a canvas-layered, centered host for dialogs
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Overlay must not block input when the menu is hidden
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_ui_layer.add_child(_overlay)
	_dialog_host = CenterContainer.new()
	_dialog_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialog_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overlay.add_child(_dialog_host)
	
	# Connect to input service for pause input
	if InputService:
		InputService.action_event.connect(_on_input_action)
	
	# Find the game scene (the level)
	_game_scene = get_tree().current_scene
	
	# Initially hidden
	visible = false


## Toggle pause state
func toggle_pause() -> void:
	if _is_paused:
		resume_game()
	else:
		pause_game()

## Pause the game and show pause menu
func pause_game() -> void:
	if _is_paused:
		return
	
	_is_paused = true
	get_tree().paused = true
	
	# Show overlay and allow it to receive mouse input while paused
	if _overlay:
		_overlay.visible = true
		_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Show pause menu
	_show_pause_menu()
	
	print("PauseMenuDemo: Game paused")

## Resume the game and hide pause menu
func resume_game() -> void:
	if not _is_paused:
		return
	
	_is_paused = false
	get_tree().paused = false
	
	# Hide overlay and stop intercepting input when not paused
	if _overlay:
		_overlay.visible = false
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Hide all dialogs
	_hide_all_dialogs()
	
	print("PauseMenuDemo: Game resumed")

## Show the pause menu dialog
func _show_pause_menu() -> void:
	visible = true
	
	# Create pause dialog
	_pause_dialog = DIALOG_TEMPLATE.instantiate() as _UITemplate
	if _pause_dialog == null:
		push_error("PauseMenuDemo: Failed to instantiate DialogTemplate")
		return
	
	# Configure dialog content
	var dialog_content = {
		StringName("title"): {
			StringName("fallback"): "Game Paused"
		},
		StringName("description"): {
			StringName("fallback"): "What would you like to do?"
		},
		StringName("actions"): [
			{
				"id": "resume",
				"label": {"fallback": "Resume"},
				"action": "resume_game"
			},
			{
				"id": "settings",
				"label": {"fallback": "Settings"},
				"action": "open_settings"
			}
		]
	}
	
	# Apply content and connect events
	_pause_dialog.apply_content(dialog_content)
	_pause_dialog.template_event.connect(_on_pause_dialog_event)
	_dialog_host.add_child(_pause_dialog)

## Show the settings menu dialog
func _show_settings_menu() -> void:
	print("PauseMenuDemo: Creating simple test dialog...")
	
	# Get current volume values directly from AudioService
	var master_db: float = AudioService.get_master_volume()
	var music_db: float = AudioService.get_music_volume()
	var master_value: float = _db_to_slider(master_db)
	var music_value: float = _db_to_slider(music_db)
	
	# Create settings dialog using SettingsTemplate properly
	_settings_dialog = SETTINGS_TEMPLATE.instantiate() as _UITemplate
	print("PauseMenuDemo: SettingsTemplate instantiated: ", _settings_dialog)
	if _settings_dialog == null:
		push_error("PauseMenuDemo: Failed to instantiate SettingsTemplate")
		return
	
	# Configure settings content
	var settings_content = {
		StringName("title"): {
			StringName("fallback"): "Settings"
		},
		StringName("sections"): [
			{
				"id": "audio",
				"title": {"fallback": "Audio Settings"},
				"controls": [
					{
						"type": "slider",
						"id": "master_volume",
						"label": {"fallback": "Master Volume"},
						"min": 0.0,
						"max": 1.0,
						"value": master_value,
						"step": 0.01
					},
					{
						"type": "slider",
						"id": "music_volume",
						"label": {"fallback": "Music Volume"},
						"min": 0.0,
						"max": 1.0,
						"value": music_value,
						"step": 0.01
					}
				]
			}
		],
		StringName("actions"): [
			{
				"id": "close",
				"label": {"fallback": "Close"}
			}
		]
	}
	
	# Add to centered host and configure
	_dialog_host.add_child(_settings_dialog)
	print("PauseMenuDemo: Settings dialog added to scene")
	
	_settings_dialog.apply_content(settings_content)
	print("PauseMenuDemo: Content applied to settings dialog")
	
	_settings_dialog.template_event.connect(_on_settings_dialog_event)
	_settings_dialog.visible = true
	print("PauseMenuDemo: Settings dialog visible: ", _settings_dialog.visible)
	print("PauseMenuDemo: Settings dialog size: ", _settings_dialog.size)
	print("PauseMenuDemo: Test dialog position: ", _settings_dialog.position)
	print("PauseMenuDemo: Test dialog size: ", _settings_dialog.size)

## Hide all dialogs
func _hide_all_dialogs() -> void:
	visible = false
	
	if _pause_dialog != null:
		_pause_dialog.queue_free()
		_pause_dialog = null
	
	if _settings_dialog != null:
		_settings_dialog.queue_free()
		_settings_dialog = null

## Handle pause dialog events
func _on_pause_dialog_event(event_id: StringName, _payload: Dictionary) -> void:
	print("PauseMenuDemo: Pause dialog event: ", event_id)
	
	match event_id:
		StringName("resume"):
			resume_game()
		StringName("settings"):
			_open_settings()

## Handle settings dialog events
func _on_settings_dialog_event(event_id: StringName, payload: Dictionary) -> void:
	print("PauseMenuDemo: Settings dialog event: ", event_id, " payload: ", payload)
	
	match event_id:
		StringName("master_volume"):
			var value: float = payload.get("value", 0.5)
			var db: float = _slider_to_db(value)
			AudioService.set_master_volume(db)
			print("Master volume set to: ", db, " dB (", value, ")")
		StringName("music_volume"):
			var value: float = payload.get("value", 0.5)
			var db: float = _slider_to_db(value)
			AudioService.set_music_volume(db)
			print("Music volume set to: ", db, " dB (", value, ")")
		StringName("close"):
			# Close settings, return to pause menu
			_settings_dialog.queue_free()
			_settings_dialog = null
			if _pause_dialog != null:
				_pause_dialog.visible = true

## Open settings menu
func _open_settings() -> void:
	print("PauseMenuDemo: Opening settings...")
	
	# Hide pause dialog
	if _pause_dialog != null:
		_pause_dialog.visible = false
		print("PauseMenuDemo: Pause dialog hidden")
	
	# Show settings dialog
	_show_settings_menu()

## Handle input actions
func _on_input_action(action: StringName, edge: String, _device: int, _event: InputEvent) -> void:
	if action == StringName("ui_cancel") and edge == "pressed":
		if _settings_dialog != null and _settings_dialog.visible:
			# Close settings, return to pause menu
			_settings_dialog.queue_free()
			_settings_dialog = null
			if _pause_dialog != null:
				_pause_dialog.visible = true
		elif _pause_dialog != null and _pause_dialog.visible:
			# Close pause menu
			resume_game()
		else:
			# No dialogs visible, toggle pause
			toggle_pause()



## Check if game is paused
func is_paused() -> bool:
	return _is_paused

## Convert bus dB volume to slider value in 0..1 range
func _db_to_slider(db: float) -> float:
	# Convert dB to linear (0..1) so mid slider ~ -6 dB (perceptual)
	if db <= VOL_DB_MIN:
		return 0.0
	var linear: float = db_to_linear(clampf(db, VOL_DB_MIN, VOL_DB_MAX))
	return clampf(linear, 0.0, 1.0)

## Convert 0..1 slider value to bus dB volume
func _slider_to_db(value: float) -> float:
	# Map linear slider (0..1) to dB using linear_to_db for perceptual response
	var v: float = clampf(value, 0.0, 1.0)
	if v <= 0.0:
		return VOL_DB_MIN
	return clampf(linear_to_db(v), VOL_DB_MIN, VOL_DB_MAX)
