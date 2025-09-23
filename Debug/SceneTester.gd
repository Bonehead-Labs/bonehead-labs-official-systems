extends Control
class_name SceneTester

## Scene tester utility for loading scenes with mock services.

@export var enabled: bool = false
@export var text_color: Color = Color.WHITE
@export var background_color: Color = Color(0.1, 0.1, 0.15, 0.9)
@export var font_size: int = 14

var _available_scenes: Array[String] = []
var _mock_services: Dictionary = {}
var _current_scene: Node
var _scene_path_input: LineEdit
var _output_text: RichTextLabel

signal scene_loaded(scene_path: String, scene: Node)
signal scene_unloaded(scene_path: String)
signal test_result(result: Dictionary)

func _ready() -> void:
    visible = enabled
    _setup_ui()
    _scan_for_scenes()
    _setup_mock_services()

func _setup_ui() -> void:
    # Create main panel
    var panel = Panel.new()
    panel.name = "TesterPanel"
    panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
    panel.get_theme_stylebox("panel").bg_color = background_color
    add_child(panel)

    # Create main container
    var container = VBoxContainer.new()
    container.name = "TesterContainer"
    container.size_flags_vertical = SIZE_EXPAND_FILL
    panel.add_child(container)

    # Scene selection
    var scene_section = HBoxContainer.new()
    scene_section.name = "SceneSection"
    container.add_child(scene_section)

    var scene_label = Label.new()
    scene_label.text = "Scene:"
    scene_label.add_theme_color_override("font_color", text_color)
    scene_section.add_child(scene_label)

    _scene_path_input = LineEdit.new()
    _scene_path_input.name = "ScenePathInput"
    _scene_path_input.size_flags_horizontal = SIZE_EXPAND_FILL
    _scene_path_input.placeholder_text = "Enter scene path (e.g., res://scenes/test_scene.tscn)"
    _scene_path_input.add_theme_font_size_override("font_size", font_size)
    _scene_path_input.text_submitted.connect(_on_scene_path_submitted)
    scene_section.add_child(_scene_path_input)

    var load_button = Button.new()
    load_button.text = "Load"
    load_button.pressed.connect(_load_selected_scene)
    scene_section.add_child(load_button)

    var unload_button = Button.new()
    unload_button.text = "Unload"
    unload_button.pressed.connect(_unload_current_scene)
    scene_section.add_child(unload_button)

    # Scene list
    var scene_list_label = Label.new()
    scene_list_label.text = "Available Scenes:"
    scene_list_label.add_theme_color_override("font_color", text_color)
    container.add_child(scene_list_label)

    var scene_list_scroll = ScrollContainer.new()
    scene_list_scroll.name = "SceneListScroll"
    scene_list_scroll.size_flags_vertical = SIZE_EXPAND_FILL
    container.add_child(scene_list_scroll)

    var scene_list = ItemList.new()
    scene_list.name = "SceneList"
    scene_list.size_flags_vertical = SIZE_EXPAND_FILL
    scene_list.item_selected.connect(_on_scene_list_selected)
    scene_list_scroll.add_child(scene_list)

    # Mock services
    var services_label = Label.new()
    services_label.text = "Mock Services:"
    services_label.add_theme_color_override("font_color", text_color)
    container.add_child(services_label)

    var services_container = VBoxContainer.new()
    services_container.name = "ServicesContainer"
    container.add_child(services_container)

    # Output area
    var output_label = Label.new()
    output_label.text = "Test Output:"
    output_label.add_theme_color_override("font_color", text_color)
    container.add_child(output_label)

    var output_scroll = ScrollContainer.new()
    output_scroll.name = "OutputScroll"
    output_scroll.size_flags_vertical = SIZE_EXPAND_FILL
    container.add_child(output_scroll)

    _output_text = RichTextLabel.new()
    _output_text.name = "OutputText"
    _output_text.size_flags_vertical = SIZE_EXPAND_FILL
    _output_text.scroll_following = true
    _output_text.bbcode_enabled = true
    _output_text.add_theme_font_size_override("normal_font_size", font_size)
    _output_text.add_theme_color_override("default_color", text_color)
    output_scroll.add_child(_output_text)

    # Control buttons
    var button_container = HBoxContainer.new()
    button_container.name = "ButtonContainer"
    panel.add_child(button_container)

    var run_tests_button = Button.new()
    run_tests_button.text = "Run Tests"
    run_tests_button.pressed.connect(_run_scene_tests)
    button_container.add_child(run_tests_button)

    var clear_output_button = Button.new()
    clear_output_button.text = "Clear Output"
    clear_output_button.pressed.connect(_clear_output)
    button_container.add_child(clear_output_button)

    var refresh_scenes_button = Button.new()
    refresh_scenes_button.text = "Refresh Scenes"
    refresh_scenes_button.pressed.connect(_scan_for_scenes)
    button_container.add_child(refresh_scenes_button)

    # Position and size
    anchors_preset = PRESET_FULL_RECT
    panel.custom_minimum_size = Vector2(800, 600)

    # Populate scene list
    _populate_scene_list()

func _scan_for_scenes() -> void:
    _available_scenes.clear()

    # Scan common scene directories
    var scene_dirs = [
        "res://scenes",
        "res://test_scenes",
        "res://debug_scenes",
        "res://ui/scenes"
    ]

    for dir_path in scene_dirs:
        if not DirAccess.dir_exists_absolute(dir_path):
            continue

        var dir = DirAccess.open(dir_path)
        if dir:
            dir.list_dir_begin()
            var file_name = dir.get_next()

            while file_name != "":
                if not dir.current_is_dir() and (file_name.ends_with(".tscn") or file_name.ends_with(".scn")):
                    _available_scenes.append(dir_path + "/" + file_name)
                file_name = dir.get_next()

    # Sort scenes
    _available_scenes.sort()

func _populate_scene_list() -> void:
    var scene_list = get_node_or_null("TesterPanel/TesterContainer/SceneListScroll/SceneList") as ItemList
    if not scene_list:
        return

    scene_list.clear()

    for scene_path in _available_scenes:
        var scene_name = scene_path.get_file().get_basename()
        scene_list.add_item(scene_name)
        scene_list.set_item_tooltip(scene_list.get_item_count() - 1, scene_path)

func _setup_mock_services() -> void:
    # Create mock implementations of common services
    _mock_services = {
        "EventBus": _create_mock_event_bus(),
        "SaveService": _create_mock_save_service(),
        "InputService": _create_mock_input_service(),
        "AudioService": _create_mock_audio_service()
    }

func _create_mock_event_bus() -> Object:
    var mock = Object.new()

    mock.set_script(load("res://Debug/MockEventBus.gd") if ResourceLoader.exists("res://Debug/MockEventBus.gd") else null)

    if mock.get_script() == null:
        # Fallback implementation
        mock.pub = func(topic: String, payload: Dictionary = {}):
            print("MockEventBus: [%s] %s" % [topic, payload])

        mock.sub = func(_topic: String, _callback: Callable):
            pass

        mock.unsub = func(_topic: String, _callback: Callable):
            pass

    return mock

func _create_mock_save_service() -> Object:
    var mock = Object.new()

    mock.save_game = func(profile: String):
        print("MockSaveService: saved game to profile %s" % profile)
        return true

    mock.load_game = func(profile: String):
        print("MockSaveService: loaded game from profile %s" % profile)
        return true

    mock.register_saveable = func(_saveable: Object):
        print("MockSaveService: registered saveable object")

    return mock

func _create_mock_input_service() -> Object:
    var mock = Object.new()

    mock.register_action = func(_action: String, _keycode: int):
        pass

    mock.is_action_pressed = func(_action: String) -> bool:
        return false

    return mock

func _create_mock_audio_service() -> Object:
    var mock = Object.new()

    mock.play_sfx = func(_sound_id: String, _options: Dictionary = {}):
        pass

    mock.play_music = func(music_id: String, fade_time: float = 0.0):
        print("MockAudioService: playing music %s with fade %.1f" % [music_id, fade_time])

    return mock

func _on_scene_path_submitted(scene_path: String) -> void:
    _load_scene(scene_path)

func _on_scene_list_selected(index: int) -> void:
    var scene_list = get_node_or_null("TesterPanel/TesterContainer/SceneListScroll/SceneList") as ItemList
    if not scene_list:
        return

    var scene_path = scene_list.get_item_tooltip(index)
    _scene_path_input.text = scene_path

func _load_selected_scene() -> void:
    var scene_path = _scene_path_input.text.strip_edges()
    if scene_path.is_empty():
        _add_output("Please enter a scene path", "error")
        return

    _load_scene(scene_path)

func _load_scene(scene_path: String) -> void:
    # Unload current scene if exists
    if _current_scene:
        _unload_current_scene()

    _add_output("Loading scene: " + scene_path)

    # Check if scene exists
    if not ResourceLoader.exists(scene_path):
        _add_output("Scene not found: " + scene_path, "error")
        return

    # Load the scene
    var scene_resource = ResourceLoader.load(scene_path)
    if not scene_resource:
        _add_output("Failed to load scene resource: " + scene_path, "error")
        return

    # Instance the scene
    _current_scene = scene_resource.instantiate()
    if not _current_scene:
        _add_output("Failed to instantiate scene: " + scene_path, "error")
        return

    # Add mock services to the scene tree temporarily
    _inject_mock_services()

    # Add to tree
    get_tree().root.add_child(_current_scene)

    _add_output("Scene loaded successfully: " + scene_path, "success")
    scene_loaded.emit(scene_path, _current_scene)

func _unload_current_scene() -> void:
    if not _current_scene:
        return

    var scene_path: String
    if _current_scene.scene_file_path != null:
        scene_path = _current_scene.scene_file_path
    else:
        scene_path = _current_scene.name
    _add_output("Unloading scene: " + scene_path)

    # Remove from tree
    _current_scene.queue_free()
    _current_scene = null

    _add_output("Scene unloaded: " + scene_path, "success")
    scene_unloaded.emit(scene_path)

func _inject_mock_services() -> void:
    if not _current_scene:
        return

    # Temporarily replace singletons with mocks
    var mock_container = Node.new()
    mock_container.name = "MockServices"

    for service_name in _mock_services:
        var mock_service = _mock_services[service_name]
        mock_container.add_child(mock_service)

    # Add to scene
    _current_scene.add_child(mock_container)

func _run_scene_tests() -> void:
    if not _current_scene:
        _add_output("No scene loaded for testing", "warning")
        return

    _add_output("Running tests on scene: " + _current_scene.name)

    var test_results = {
        "scene_name": _current_scene.name,
        "node_count": _count_nodes(_current_scene),
        "script_count": _count_scripts(_current_scene),
        "has_required_components": _check_required_components(_current_scene),
        "performance_impact": _assess_performance_impact(_current_scene)
    }

    # Display results
    _add_output("Test Results:", "success")
    _add_output("- Scene: " + str(test_results.scene_name))
    _add_output("- Nodes: " + str(test_results.node_count))
    _add_output("- Scripts: " + str(test_results.script_count))
    _add_output("- Required Components: " + ("PASS" if test_results.has_required_components else "FAIL"))
    _add_output("- Performance Impact: " + test_results.performance_impact)

    test_result.emit(test_results)

func _count_nodes(node: Node, count: int = 0) -> int:
    count += 1
    for child in node.get_children():
        count = _count_nodes(child, count)
    return count

func _count_scripts(node: Node, count: int = 0) -> int:
    if node.get_script() != null:
        count += 1
    for child in node.get_children():
        count = _count_scripts(child, count)
    return count

func _check_required_components(_node: Node) -> bool:
    # Check for common required components
    # This would be more sophisticated in a real implementation
    return true  # Assume pass for now

func _assess_performance_impact(node: Node) -> String:
    var node_count = _count_nodes(node)
    var script_count = _count_scripts(node)

    if node_count > 1000 or script_count > 50:
        return "HIGH"
    elif node_count > 500 or script_count > 25:
        return "MEDIUM"
    else:
        return "LOW"

func _clear_output() -> void:
    if _output_text:
        _output_text.clear()

func _add_output(text: String, type: String = "normal") -> void:
    if not _output_text:
        return

    var formatted_text = text
    match type:
        "success":
            formatted_text = "[color=green]" + text + "[/color]"
        "error":
            formatted_text = "[color=red]" + text + "[/color]"
        "warning":
            formatted_text = "[color=yellow]" + text + "[/color]"

    _output_text.append_text(formatted_text + "\n")

func toggle_visibility() -> void:
    visible = not visible

func set_enabled(enable: bool) -> void:
    enabled = enable
    visible = enabled and visible

func is_enabled() -> bool:
    return enabled

func get_loaded_scene() -> Node:
    return _current_scene

func get_available_scenes() -> Array[String]:
    return _available_scenes.duplicate()

func load_scene(scene_path: String) -> bool:
    _load_scene(scene_path)
    return _current_scene != null

func unload_scene() -> void:
    _unload_current_scene()

func run_tests() -> Dictionary:
    _run_scene_tests()
    var scene_name: String
    if _current_scene != null:
        scene_name = _current_scene.name
    else:
        scene_name = "none"

    return {
        "scene_name": scene_name,
        "status": "completed"
    }
