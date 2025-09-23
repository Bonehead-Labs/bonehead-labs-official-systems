extends Control
class_name DebugConsole

## In-game console with command registry and security gating.

@export var enabled: bool = false
@export var command_history_size: int = 50
@export var text_color: Color = Color.WHITE
@export var background_color: Color = Color(0.1, 0.1, 0.1, 0.95)
@export var font_size: int = 14
@export var auto_complete_enabled: bool = true

var _command_history: Array[String] = []
var _history_index: int = -1
var _current_command: String = ""
var _is_visible: bool = false
var _commands: Dictionary = {}
var _security_level: int = 0  # 0 = disabled, 1 = basic, 2 = advanced, 3 = admin
var _access_log: Array[String] = []

signal command_executed(command: String, result: String, success: bool)
signal console_toggled(visible: bool)

func _ready() -> void:
    visible = enabled and _is_visible
    _setup_ui()
    _register_default_commands()

func _setup_ui() -> void:
    # Create main panel
    var panel = Panel.new()
    panel.name = "ConsolePanel"
    panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
    panel.get_theme_stylebox("panel").bg_color = background_color
    add_child(panel)

    # Create main container
    var container = VBoxContainer.new()
    container.name = "ConsoleContainer"
    container.size_flags_vertical = SIZE_EXPAND_FILL
    panel.add_child(container)

    # Create output text area
    var output_scroll = ScrollContainer.new()
    output_scroll.name = "OutputScroll"
    output_scroll.size_flags_vertical = SIZE_EXPAND_FILL
    container.add_child(output_scroll)

    var output_text = RichTextLabel.new()
    output_text.name = "OutputText"
    output_text.size_flags_vertical = SIZE_EXPAND_FILL
    output_text.scroll_following = true
    output_text.bbcode_enabled = true
    output_text.add_theme_font_size_override("normal_font_size", font_size)
    output_text.add_theme_color_override("default_color", text_color)
    output_scroll.add_child(output_text)

    # Create input container
    var input_container = HBoxContainer.new()
    input_container.name = "InputContainer"
    container.add_child(input_container)

    # Command prompt
    var prompt_label = Label.new()
    prompt_label.text = "> "
    prompt_label.add_theme_color_override("font_color", text_color)
    input_container.add_child(prompt_label)

    # Command input
    var command_input = LineEdit.new()
    command_input.name = "CommandInput"
    command_input.size_flags_horizontal = SIZE_EXPAND_FILL
    command_input.add_theme_font_size_override("font_size", font_size)
    command_input.text_submitted.connect(_on_command_submitted)
    command_input.text_changed.connect(_on_command_changed)
    input_container.add_child(command_input)

    # Position and size
    anchors_preset = PRESET_BOTTOM_LEFT
    panel.custom_minimum_size = Vector2(800, 300)

    # Focus input when shown
    command_input.grab_focus()

func _register_default_commands() -> void:
    # Basic commands
    register_command("help", _cmd_help, "Show available commands", 1)
    register_command("clear", _cmd_clear, "Clear console output", 1)
    register_command("history", _cmd_history, "Show command history", 1)
    register_command("echo", _cmd_echo, "Echo text", 1)

    # Debug commands
    register_command("fps", _cmd_fps, "Show FPS", 1)
    register_command("memory", _cmd_memory, "Show memory usage", 1)
    register_command("objects", _cmd_objects, "Show object counts", 1)

    # System commands
    register_command("screenshot", _cmd_screenshot, "Take screenshot", 1)
    register_command("scene", _cmd_scene_info, "Show current scene info", 1)
    register_command("tree", _cmd_scene_tree, "Show scene tree", 2)

    # Cheat commands (higher security level)
    register_command("god", _cmd_god_mode, "Toggle god mode", 2)
    register_command("noclip", _cmd_noclip, "Toggle noclip mode", 2)
    register_command("give", _cmd_give_item, "Give item (format: give item_id quantity)", 2)

    # Admin commands (highest security level)
    register_command("spawn", _cmd_spawn_enemy, "Spawn enemy (format: spawn enemy_type x y)", 3)
    register_command("teleport", _cmd_teleport, "Teleport player (format: teleport x y)", 3)
    register_command("killall", _cmd_kill_all, "Kill all enemies", 3)

func register_command(command_name: String, command_func: Callable, description: String, required_level: int = 1) -> void:
    _commands[command_name] = {
        "function": command_func,
        "description": description,
        "required_level": required_level
    }

func _input(event: InputEvent) -> void:
    if not enabled:
        return

    # Toggle console visibility
    if event.is_action_pressed("debug_toggle_console"):
        toggle_visibility()

    # Handle console-specific input when visible
    if _is_visible:
        if event.is_action_pressed("ui_up"):
            _navigate_history(-1)
        elif event.is_action_pressed("ui_down"):
            _navigate_history(1)
        elif event.is_action_pressed("ui_page_up"):
            _scroll_output(-10)
        elif event.is_action_pressed("ui_page_down"):
            _scroll_output(10)

func _on_command_submitted(command: String) -> void:
    if command.strip_edges().is_empty():
        return

    _add_output("> " + command, "input")

    # Check security level
    var command_data = _commands.get(command.split(" ")[0], {})
    var required_level = command_data.get("required_level", 1)

    if _security_level < required_level:
        _add_output("Access denied. Required security level: " + str(required_level), "error")
        return

    # Log access for security auditing
    _log_access(command)

    # Execute command
    var result = _execute_command(command)
    var success = result != "Command not found"

    if success:
        _add_output(result, "success")
    else:
        _add_output(result, "error")

    command_executed.emit(command, result, success)

    # Add to history
    _command_history.append(command)
    if _command_history.size() > command_history_size:
        _command_history.remove_at(0)
    _history_index = -1

func _on_command_changed(new_text: String) -> void:
    _current_command = new_text

func _execute_command(command: String) -> String:
    var parts = command.split(" ")
    var cmd_name = parts[0]
    var args = parts.slice(1)

    var command_data = _commands.get(cmd_name, {})
    if command_data.is_empty():
        return "Command not found. Type 'help' for available commands."

    var cmd_func = command_data["function"]
    return cmd_func.call(args)

func _navigate_history(direction: int) -> void:
    if _command_history.is_empty():
        return

    _history_index = clamp(_history_index + direction, -1, _command_history.size() - 1)

    var input_field = get_node_or_null("ConsolePanel/ConsoleContainer/InputContainer/CommandInput") as LineEdit
    if input_field:
        if _history_index == -1:
            input_field.text = _current_command
        else:
            input_field.text = _command_history[_history_index]

func _scroll_output(lines: int) -> void:
    var output_text = get_node_or_null("ConsolePanel/ConsoleContainer/OutputScroll/OutputText") as RichTextLabel
    if output_text:
        var scroll_bar = output_text.get_v_scroll_bar()
        if scroll_bar:
            scroll_bar.value += lines * font_size

func _add_output(text: String, type: String = "normal") -> void:
    var output_text = get_node_or_null("ConsolePanel/ConsoleContainer/OutputScroll/OutputText") as RichTextLabel
    if not output_text:
        return

    var formatted_text = text
    match type:
        "input":
            formatted_text = "[color=cyan]" + text + "[/color]"
        "success":
            formatted_text = "[color=green]" + text + "[/color]"
        "error":
            formatted_text = "[color=red]" + text + "[/color]"
        "warning":
            formatted_text = "[color=yellow]" + text + "[/color]"

    output_text.append_text(formatted_text + "\n")

func _log_access(command: String) -> void:
    var timestamp = Time.get_time_dict_from_system()
    var log_entry = "[%02d:%02d:%02d] Command: %s (Level: %d)" % [
        timestamp.hour, timestamp.minute, timestamp.second, command, _security_level
    ]
    _access_log.append(log_entry)

    # Keep only recent entries
    if _access_log.size() > 100:
        _access_log.remove_at(0)

## Command implementations
func _cmd_help(_args: Array) -> String:
    var output = "Available commands:\n"
    for cmd_name in _commands:
        var cmd_data = _commands[cmd_name]
        var required_level = cmd_data["required_level"]
        if _security_level >= required_level:
            output += "  %s - %s\n" % [cmd_name, cmd_data["description"]]
    return output

func _cmd_clear(_args: Array) -> String:
    var output_text = get_node_or_null("ConsolePanel/ConsoleContainer/OutputScroll/OutputText") as RichTextLabel
    if output_text:
        output_text.clear()
    return "Console cleared"

func _cmd_history(_args: Array) -> String:
    if _command_history.is_empty():
        return "No command history"

    var output = "Command history:\n"
    for i in range(_command_history.size()):
        output += "  %d: %s\n" % [i + 1, _command_history[i]]
    return output

func _cmd_echo(args: Array) -> String:
    return " ".join(args) if args.size() > 0 else ""

func _cmd_fps(_args: Array) -> String:
    return "FPS: %.1f, Frame Time: %.2f ms" % [
        Performance.get_monitor(Performance.TIME_FPS),
        Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
    ]

func _cmd_memory(_args: Array) -> String:
    var static_mem = Performance.get_monitor(Performance.MEMORY_STATIC)
    var total_mem = static_mem
    return "Memory Usage: %.1f MB (Static: %.1f MB)" % [
        total_mem / (1024.0 * 1024.0),
        static_mem / (1024.0 * 1024.0)
    ]

func _cmd_objects(_args: Array) -> String:
    return "Objects: %d, Nodes: %d" % [
        Performance.get_monitor(Performance.OBJECT_COUNT),
        Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
    ]

func _cmd_screenshot(_args: Array) -> String:
    var timestamp = Time.get_time_dict_from_system()
    var filename = "debug_screenshot_%04d%02d%02d_%02d%02d%02d.png" % [
        timestamp.year, timestamp.month, timestamp.day,
        timestamp.hour, timestamp.minute, timestamp.second
    ]

    var image = get_viewport().get_texture().get_image()
    var result = image.save_png(filename)

    if result == OK:
        return "Screenshot saved: " + filename
    return "Failed to save screenshot"

func _cmd_scene_info(_args: Array) -> String:
    var scene = get_tree().current_scene
    if scene:
        return "Current scene: %s (%s)" % [scene.name, scene.scene_file_path]
    return "No current scene"

func _cmd_scene_tree(_args: Array) -> String:
    var output = "Scene tree:\n"
    _build_tree_string(get_tree().root, output, 0)
    return output

func _cmd_god_mode(_args: Array) -> String:
    # This would need to integrate with the game's god mode system
    return "God mode toggled (not implemented in base system)"

func _cmd_noclip(_args: Array) -> String:
    # This would need to integrate with the player's movement system
    return "Noclip mode toggled (not implemented in base system)"

func _cmd_give_item(args: Array) -> String:
    if args.size() < 2:
        return "Usage: give item_id quantity"

    var item_id = args[0]
    var quantity = int(args[1])

    # This would need to integrate with the Items & Economy system
    return "Gave %d x %s (not implemented in base system)" % [quantity, item_id]

func _cmd_spawn_enemy(args: Array) -> String:
    if args.size() < 3:
        return "Usage: spawn enemy_type x y"

    var enemy_type = args[0]
    var x = float(args[1])
    var y = float(args[2])

    # This would need to integrate with the Enemy AI system
    return "Spawned %s at (%.1f, %.1f) (not implemented in base system)" % [enemy_type, x, y]

func _cmd_teleport(args: Array) -> String:
    if args.size() < 2:
        return "Usage: teleport x y"

    var x = float(args[0])
    var y = float(args[1])

    # This would need to integrate with the Player Controller system
    return "Teleported player to (%.1f, %.1f) (not implemented in base system)" % [x, y]

func _cmd_kill_all(_args: Array) -> String:
    # This would need to integrate with the Enemy AI and Combat systems
    return "Killed all enemies (not implemented in base system)"

func _build_tree_string(node: Node, output: String, depth: int) -> void:
    var indent = "  ".repeat(depth)
    output += indent + node.name + " (" + node.get_class() + ")\n"

    for child in node.get_children():
        _build_tree_string(child, output, depth + 1)

func toggle_visibility() -> void:
    _is_visible = not _is_visible
    visible = enabled and _is_visible
    console_toggled.emit(_is_visible)

func set_enabled(enable: bool) -> void:
    enabled = enable
    if not enabled:
        visible = false
        _is_visible = false

func is_enabled() -> bool:
    return enabled

func set_security_level(level: int) -> void:
    _security_level = clamp(level, 0, 3)

func get_security_level() -> int:
    return _security_level

func get_access_log() -> Array[String]:
    return _access_log.duplicate()

func clear_access_log() -> void:
    _access_log.clear()
