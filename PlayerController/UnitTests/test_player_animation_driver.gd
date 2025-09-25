extends "res://addons/gut/test.gd"

## Test PlayerAnimationDriver functionality
## Uses a simplified approach that doesn't override native methods

const DriverScriptPath: String = "res://PlayerController/Animation/PlayerAnimationDriver.gd"
const ConfigPath: String = "res://PlayerController/default_movement.tres"

var controller: _PlayerController2D
var driver: PlayerAnimationDriver
var animation_player: AnimationPlayer
var animated_sprite: AnimatedSprite2D

func before_each() -> void:
    controller = _PlayerController2D.new()
    controller.name = "TestController"
    get_tree().root.add_child(controller)
    
    animation_player = AnimationPlayer.new()
    animation_player.name = "TestAnimationPlayer"
    get_tree().root.add_child(animation_player)
    
    animated_sprite = AnimatedSprite2D.new()
    animated_sprite.name = "TestAnimatedSprite"
    get_tree().root.add_child(animated_sprite)
    
    driver = PlayerAnimationDriver.new()
    driver.name = "TestDriver"
    get_tree().root.add_child(driver)
    
    # Configure driver
    driver.controller_path = NodePath("TestController")
    driver.animation_player_path = NodePath("TestAnimationPlayer")
    driver.animated_sprite_path = NodePath("TestAnimatedSprite")
    
    # Set up state animation map
    driver.state_animation_map = {
        "idle": "idle_anim",
        "move": "run_anim",
        "jump": "jump_anim"
    }
    
    # Set up event animation map
    driver.event_animation_map = {
        "landed": "land_anim"
    }
    
    # Add some test animations to the animation player
    var idle_anim = Animation.new()
    var run_anim = Animation.new()
    var jump_anim = Animation.new()
    
    animation_player.add_animation("idle_anim", idle_anim)
    animation_player.add_animation("run_anim", run_anim)
    animation_player.add_animation("jump_anim", jump_anim)
    
    # Add some test animations to the animated sprite
    var sprite_frames = SpriteFrames.new()
    sprite_frames.add_animation("fall_anim")
    animated_sprite.sprite_frames = sprite_frames
    
    await get_tree().process_frame

func after_each() -> void:
    if driver:
        driver.queue_free()
    if controller:
        controller.queue_free()
    if animation_player:
        animation_player.queue_free()
    if animated_sprite:
        animated_sprite.queue_free()

func test_driver_initializes_correctly() -> void:
    """Test that the driver initializes with correct node references."""
    assert_not_null(driver._controller, "Controller should be resolved")
    assert_not_null(driver._animation_player, "AnimationPlayer should be resolved")
    assert_not_null(driver._animated_sprite, "AnimatedSprite should be resolved")

func test_state_changes_trigger_animations() -> void:
    """Test that state changes trigger appropriate animations."""
    # Test idle state
    controller.transition_to_state(StringName("idle"))
    await get_tree().process_frame
    assert_eq(animation_player.current_animation, "idle_anim")
    
    # Test move state
    controller.transition_to_state(StringName("move"))
    await get_tree().process_frame
    assert_eq(animation_player.current_animation, "run_anim")
    
    # Test jump state
    controller.transition_to_state(StringName("jump"))
    await get_tree().process_frame
    assert_eq(animation_player.current_animation, "jump_anim")

func test_event_animations_override_state() -> void:
    """Test that event animations can override state animations."""
    # Set up override
    driver.set_animation_override("special_anim", "test_source")
    await get_tree().process_frame
    assert_eq(animation_player.current_animation, "special_anim")
    
    # Clear override
    driver.clear_animation_override("test_source")
    await get_tree().process_frame
    # Should return to current state animation
    assert_eq(animation_player.current_animation, "jump_anim")

func test_fallback_uses_animated_sprite_when_player_missing_animation() -> void:
    """Test that fallback uses AnimatedSprite when AnimationPlayer is missing animation."""
    # Remove animation player to force fallback
    driver._animation_player = null
    
    # Set up fallback animation
    driver.fallback_animation = "fall_anim"
    
    # Trigger state change
    controller.transition_to_state(StringName("idle"))
    await get_tree().process_frame
    
    # Should use AnimatedSprite fallback
    assert_eq(animated_sprite.animation, "fall_anim")

func _physics_steps(count: int) -> void:
    """Helper to step physics multiple times."""
    for i in count:
        await get_tree().physics_frame