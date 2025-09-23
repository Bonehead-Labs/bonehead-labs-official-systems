extends Node
class_name WorldTimeManager

## Optional world time manager stub with pause/resume API.

var _is_paused: bool = false
var _time_scale: float = 1.0
var _game_time: float = 0.0  # Total game time in seconds

signal time_paused()
signal time_resumed()
signal time_scale_changed(new_scale: float)
signal game_time_updated(game_time: float)

func _process(delta: float) -> void:
    if not _is_paused:
        var scaled_delta: float = delta * _time_scale
        _game_time += scaled_delta
        game_time_updated.emit(_game_time)

func pause_time() -> void:
    if not _is_paused:
        _is_paused = true
        time_paused.emit()

        if Engine.has_singleton("EventBus"):
            Engine.get_singleton("EventBus").call("pub", &"world/time_paused", {
                "game_time": _game_time
            })

func resume_time() -> void:
    if _is_paused:
        _is_paused = false
        time_resumed.emit()

        if Engine.has_singleton("EventBus"):
            Engine.get_singleton("EventBus").call("pub", &"world/time_resumed", {
                "game_time": _game_time
            })

func set_time_scale(scale: float) -> void:
    var clamped_scale: float = clamp(scale, 0.0, 10.0)
    if _time_scale != clamped_scale:
        _time_scale = clamped_scale
        time_scale_changed.emit(_time_scale)

        if Engine.has_singleton("EventBus"):
            Engine.get_singleton("EventBus").call("pub", &"world/time_scale_changed", {
                "time_scale": _time_scale,
                "game_time": _game_time
            })

func get_time_scale() -> float:
    return _time_scale

func is_paused() -> bool:
    return _is_paused

func get_game_time() -> float:
    return _game_time

func set_game_time(time: float) -> void:
    _game_time = max(0.0, time)
    game_time_updated.emit(_game_time)

func reset_game_time() -> void:
    _game_time = 0.0
    game_time_updated.emit(_game_time)

## Save/Load integration
func save_data() -> Dictionary:
    return {
        "game_time": _game_time,
        "time_scale": _time_scale,
        "is_paused": _is_paused
    }

func load_data(data: Dictionary) -> bool:
    _game_time = data.get("game_time", 0.0)
    set_time_scale(data.get("time_scale", 1.0))

    var was_paused: bool = data.get("is_paused", false)
    if was_paused:
        pause_time()
    else:
        resume_time()

    return true

## Extension points for future time-of-day system
func get_time_of_day() -> Dictionary:
    # Stub implementation - could be extended for day/night cycles
    return {
        "hour": 12,
        "minute": 0,
        "second": 0,
        "day_progress": 0.5  # 0.0 to 1.0
    }

func set_time_of_day(_hour: int, _minute: int = 0, _second: int = 0) -> void:
    # Stub implementation - could trigger lighting changes, enemy behavior, etc.
    pass

func advance_time_by(hours: float) -> void:
    # Stub implementation - could be used for time travel mechanics
    var seconds_to_advance: float = hours * 3600.0
    set_game_time(_game_time + seconds_to_advance)
