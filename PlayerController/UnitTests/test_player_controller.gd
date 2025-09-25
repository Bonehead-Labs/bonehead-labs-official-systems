extends "res://addons/gut/test.gd"

const ConfigPath: String = "res://PlayerController/default_movement.tres"

class TestController extends _PlayerController2D:
    var floor_override: bool = is_on_floor()

var controller: TestController
var config: MovementConfig
var event_bus: Node

class EventBusStub extends Node:
    var calls: Array = []
    func pub(topic: StringName, payload: Dictionary) -> void:
        calls.append({"topic": topic, "payload": payload})

func before_each() -> void:
    controller = TestController.new()
    config = (load(ConfigPath) as MovementConfig).duplicate_config()
    controller.set_config(config)
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

func _physics_steps(frames: int = 1, delta: float = 0.016) -> void:
    for i in range(frames):
        controller._process(delta)
        controller._physics_process(delta)

func test_platformer_moves_from_idle_to_move() -> void:
    controller.floor_override = true
    controller.set_manual_input(Vector2.RIGHT)
    _physics_steps(5)
    assert_eq(controller.get_current_state(), StringName("move"))
    assert_gt(controller.get_motion_velocity().x, 0.0)

func test_jump_transitions_through_air_states() -> void:
    controller.floor_override = true
    controller.set_manual_input(Vector2.ZERO)
    controller.movement_config.jump_velocity = -300.0
    controller.refresh_coyote_timer()
    var jump_event := InputEventAction.new()
    jump_event.action = controller.movement_config.jump_action
    controller._on_action_event(controller.movement_config.jump_action, "pressed", 0, jump_event)
    _physics_steps(1)
    assert_eq(controller.get_current_state(), StringName("jump"))
    assert_eq(controller.get_motion_velocity().y, controller.movement_config.jump_velocity)
    controller.floor_override = false
    _physics_steps(12)
    assert_eq(controller.get_current_state(), StringName("fall"))
    controller.floor_override = true
    _physics_steps(2)
    assert_eq(controller.get_current_state(), StringName("idle"))

func test_top_down_movement_uses_move_state_and_diagonal_velocity() -> void:
    controller.movement_config.movement_mode = MovementConfig.MovementMode.TOP_DOWN
    controller.movement_config.allow_jump = false
    controller.movement_config.allow_vertical_input = true
    controller.set_config(controller.movement_config)
    controller.set_manual_input(Vector2(1.0, -1.0).normalized())
    _physics_steps(6)
    assert_eq(controller.get_current_state(), StringName("move"))
    var velocity := controller.get_motion_velocity()
    assert_gt(velocity.x, 0.0)
    assert_lt(velocity.y, 0.0)
    assert_ne(controller.transition_to_state(StringName("jump")), OK)
    controller.set_manual_input(Vector2.ZERO)
    _physics_steps(4)
    assert_eq(controller.get_current_state(), StringName("idle"))

func test_spawn_emits_signal() -> void:
    var called := false
    controller.player_spawned.connect(func(_pos: Vector2): called = true)
    controller.spawn(Vector2(100, 50))
    assert_true(called)
    assert_eq(controller.global_position, Vector2(100, 50))

func test_eventbus_input_handling() -> void:
    """Test that PlayerController responds to EventBus input events."""
    # Disable manual input to test EventBus integration
    controller.enable_manual_input(false)
    
    # Simulate EventBus axis event for movement
    var axis_payload := {
        "axis": StringName("move_x"),
        "value": 1.0,
        "device": 0
    }
    controller._on_eventbus_axis(axis_payload)
    
    # Check that axis value was stored
    assert_eq(controller._axis_values.get(StringName("move_x"), 0.0), 1.0)
    
    # Test movement input retrieval
    var input_vector := controller.get_movement_input()
    assert_eq(input_vector.x, 1.0)
    assert_eq(input_vector.y, 0.0)
    
    # Test vertical movement
    var vertical_payload := {
        "axis": StringName("move_y"),
        "value": -1.0,
        "device": 0
    }
    controller._on_eventbus_axis(vertical_payload)
    
    # Enable vertical input for this test
    controller.movement_config.allow_vertical_input = true
    input_vector = controller.get_movement_input()
    assert_eq(input_vector.x, 1.0)
    assert_eq(input_vector.y, -1.0)

func test_eventbus_action_handling() -> void:
    """Test that PlayerController responds to EventBus action events."""
    # Disable manual input to test EventBus integration
    controller.enable_manual_input(false)
    
    # Test jump action by checking if it can consume jump request
    var jump_payload := {
        "action": StringName("jump"),
        "edge": "pressed",
        "device": 0
    }
    controller._on_eventbus_action(jump_payload)
    
    # Test that jump request can be consumed (indirect test of jump buffer)
    controller.floor_override = true
    var can_consume = controller.consume_jump_request()
    assert_true(can_consume, "Jump request should be consumable after EventBus action")
    
    # Test interact action
    var interact_payload := {
        "action": StringName("interact"),
        "edge": "pressed",
        "device": 0
    }
    # This should not crash (interact() method should be callable)
    controller._on_eventbus_action(interact_payload)
