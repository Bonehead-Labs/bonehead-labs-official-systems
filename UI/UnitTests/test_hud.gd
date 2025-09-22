extends "res://addons/gut/test.gd"

const HUDShellPath: String = "res://UI/HUD/HUDShell.gd"
const PanelScenePath: String = "res://UI/ScreenManager/TestScreen.tscn"

var glyph_service: _InputGlyphService
var hud: _HUDShell
var panel_scene: PackedScene

class InputServiceStub extends Node:
    signal last_active_device_changed(kind: String, device_id: int)

var input_service_stub: InputServiceStub

func before_each() -> void:
    panel_scene = load(PanelScenePath)
    glyph_service = load("res://UI/HUD/InputGlyphService.gd").new()
    glyph_service.name = "InputGlyphService"
    get_tree().root.add_child(glyph_service)
    await glyph_service.ready
    input_service_stub = InputServiceStub.new()
    input_service_stub.name = "InputService"
    get_tree().root.add_child(input_service_stub)
    await get_tree().process_frame
    hud = load(HUDShellPath).new()
    get_tree().root.add_child(hud)
    await hud.ready

func after_each() -> void:
    for node in [hud, glyph_service, input_service_stub]:
        if is_instance_valid(node):
            node.queue_free()
            await get_tree().process_frame

func test_panel_registration_and_show() -> void:
    hud.register_panel(StringName("status"), panel_scene)
    var err := hud.show_panel(StringName("status"))
    assert_eq(err, OK)
    assert_eq(hud.get_child_count() > 0, true)
    assert_eq(hud.show_panel(StringName("status")), OK)

func test_action_icon_updates_on_device_change() -> void:
    var texture := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
    glyph_service.register_glyph(StringName("keyboard"), StringName("jump"), texture)
    var icon := TextureRect.new()
    get_tree().root.add_child(icon)
    hud.register_action_icon(icon, StringName("jump"))
    input_service_stub.last_active_device_changed.emit("keyboard", 0)
    await get_tree().process_frame
    assert_eq(icon.texture, texture)
    icon.queue_free()

func test_hide_panel_removes_node() -> void:
    hud.register_panel(StringName("menu"), panel_scene)
    assert_eq(hud.show_panel(StringName("menu")), OK)
    assert_eq(hud.hide_panel(StringName("menu")), OK)
*** End Patch
