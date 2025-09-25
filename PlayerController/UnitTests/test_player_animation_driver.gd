extends "res://addons/gut/test.gd"

const DriverScriptPath: String = "res://PlayerController/Animation/PlayerAnimationDriver.gd"
const ConfigPath: String = "res://PlayerController/default_movement.tres"

class TestController extends _PlayerController2D:
    var floor_override: bool = false

    func is_on_floor() -> bool:
        return floor_override

class TestAnimationPlayer extends AnimationPlayer:
    var animations: Dictionary = {}
    var played: Array[StringName] = []

    func has_animation(anim: StringName) -> bool:
        return animations.has(anim)

    func play(anim: StringName, custom_blend: float = -1.0, custom_speed: float = 1.0, from_end: bool = false) -> void:
        played.append(anim)

class TestSpriteFrames extends SpriteFrames:
    var available: Dictionary = {}

    func has_animation(anim: StringName) -> bool:
        return available.has(anim)

class TestAnimatedSprite extends AnimatedSprite2D:
    var played: Array[StringName] = []

    func play(anim: StringName, custom_speed: float = 1.0, from_end: bool = false) -> void:
        played.append(anim)

var controller: TestController
var driver: PlayerAnimationDriver
var animation_player: TestAnimationPlayer
var animated_sprite: TestAnimatedSprite

func before_each() -> void:
    controller = TestController.new()
    controller.set_config((load(ConfigPath) as MovementConfig).duplicate_config())
    controller.enable_manual_input(true)
    controller.name = "PlayerController"
    animation_player = TestAnimationPlayer.new()
    animation_player.animations = {
        StringName("idle_anim"): true,
        StringName("run_anim"): true,
        StringName("jump_anim"): true
    }
    animated_sprite = TestAnimatedSprite.new()
    var frames := TestSpriteFrames.new()
    frames.available = {
        StringName("idle_anim"): true,
        StringName("fall_anim"): true
    }
    animated_sprite.sprite_frames = frames
    animated_sprite.name = "AnimatedSprite"
    driver = load(DriverScriptPath).new()
    driver.name = "AnimationDriver"
    driver.state_animation_map = {
        StringName("idle"): "idle_anim",
        StringName("move"): "run_anim",
        StringName("jump"): "jump_anim"
    }
    driver.event_animation_map = {
        StringName("jump_started"): "jump_anim",
        StringName("fall_entered"): "fall_anim"
    }
    driver.fallback_animation = StringName("idle_anim")
    get_tree().root.add_child(controller)
    get_tree().root.add_child(animation_player)
    get_tree().root.add_child(animated_sprite)
    await controller.ready
    driver.controller_path = controller.get_path()
    driver.animation_player_path = animation_player.get_path()
    driver.animated_sprite_path = animated_sprite.get_path()
    get_tree().root.add_child(driver)
    await controller.ready
    await driver.ready

func after_each() -> void:
    for node in [driver, animation_player, animated_sprite, controller]:
        if is_instance_valid(node):
            node.queue_free()
    await get_tree().process_frame

func _step_controller(frames: int, delta: float = 0.016) -> void:
    for i in range(frames):
        controller._process(delta)
        controller._physics_process(delta)

func test_state_change_plays_mapped_animation() -> void:
    controller.set_manual_input(Vector2.ZERO)
    controller.movement_config.allow_jump = true
    controller.movement_config.allow_vertical_input = false
    controller.movement_config.movement_mode = MovementConfig.MovementMode.PLATFORMER
    _step_controller(1)
    assert_true(animation_player.played.has(StringName("idle_anim")))
    controller.set_manual_input(Vector2.RIGHT)
    _step_controller(6)
    assert_true(animation_player.played.has(StringName("run_anim")))

func test_event_override_plays_jump_animation() -> void:
    controller.movement_config.allow_jump = true
    controller.movement_config.movement_mode = MovementConfig.MovementMode.PLATFORMER
    controller.floor_override = true
    controller.set_manual_input(Vector2.ZERO)
    controller.refresh_coyote_timer()
    var jump_event := InputEventAction.new()
    jump_event.action = controller.movement_config.jump_action
    controller._on_action_event(controller.movement_config.jump_action, "pressed", 0, jump_event)
    _step_controller(1)
    assert_true(animation_player.played.has(StringName("jump_anim")))

func test_fallback_uses_animated_sprite_when_player_missing_animation() -> void:
    animation_player.animations.erase(StringName("fall_anim"))
    controller.movement_config.allow_jump = true
    controller.floor_override = true
    controller.set_manual_input(Vector2.ZERO)
    controller.refresh_coyote_timer()
    var jump_event := InputEventAction.new()
    jump_event.action = controller.movement_config.jump_action
    controller._on_action_event(controller.movement_config.jump_action, "pressed", 0, jump_event)
    _step_controller(1)
    controller.floor_override = false
    _step_controller(20)
    assert_true(animated_sprite.played.has(StringName("fall_anim")))
