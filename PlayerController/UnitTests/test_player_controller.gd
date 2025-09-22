extends "res://addons/gut/test.gd"

const ControllerPath: String = "res://PlayerController/PlayerController.gd"
const ConfigPath: String = "res://PlayerController/default_movement.tres"

class TestController extends _PlayerController2D:
    var floor_override: bool = false

    func is_on_floor() -> bool:
        return floor_override

var controller: TestController
var config: MovementConfig
var event_bus: Node

class EventBusStub extends Node:
    var calls: Array = []
    func pub(topic: StringName, payload: Dictionary) -> void:
        calls.append({"topic": topic, "payload": payload})

func before_each() -> void:
    controller = TestController.new()
    config = load(ConfigPath)
    controller.movement_config = config
    controller.enable_manual_input(true)
    controller.name = "PlayerController"
    event_bus = EventBusStub.new()
    event_bus.name = "EventBus"
    get_tree().root.add_child(event_bus)
    get_tree().root.add_child(controller)
    await controller.ready

func after_each() -> void:
    if is_instance_valid(event_bus):
        event_bus.queue_free()
        await get_tree().process_frame
    if is_instance_valid(controller):
        controller.queue_free()
        await get_tree().process_frame

func test_manual_horizontal_acceleration() -> void:
    controller.set_manual_input(Vector2.RIGHT)
    controller._apply_horizontal(0.1)
    assert_gt(controller.get_velocity().x, 0.0)

func test_jump_uses_coyote_and_buffer() -> void:
    controller.movement_config.jump_velocity = -300.0
    controller._coyote_timer = controller.movement_config.coyote_time
    controller._jump_buffer_timer = controller.movement_config.jump_buffer_time
    controller.floor_override = true
    controller._apply_vertical(0.016)
    assert_eq(controller.get_velocity().y, controller.movement_config.jump_velocity)

func test_spawn_emits_signal() -> void:
    var called := false
    controller.player_spawned.connect(func(_pos: Vector2): called = true)
    controller.spawn(Vector2(100, 50))
    assert_true(called)
    assert_eq(controller.global_position, Vector2(100, 50))
