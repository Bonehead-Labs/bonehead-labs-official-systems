class_name EventBus extends Node

var _subs: Dictionary = {} #Dictionary[StringName, Array[Callable]]
var deferred_mode: bool = false

# Subscribe to an event
func sub(topic: StringName, cb: Callable) -> void:
    var key = StringName(topic)
    var arr: Array = _subs.get(key, [])
    if not arr.has(cb):
        arr.append(cb)
    _subs[key] = arr


func unsub(topic: StringName, cb: Callable) -> void:
    var key := StringName(topic)
    if not _subs.has(key):
        return
    _subs[key].erase(cb)
    if _subs[key].is_empty():
        _subs.erase(key)


func pub(topic: StringName, payload: Dictionary = {}, use_envelope: bool = false) -> void:
    var key := StringName(topic)
    var envelope: Dictionary = {
        "topic": key,
        "payload": payload,
        "timestamp": Time.get_ticks_msec(),
        "frame": Engine.get_frames_drawn()
    }
    if not _subs.has(key):
        return
    var listeners: Array = _subs[key].duplicate()
    if deferred_mode:
        # Schedule dispatch safely
        call_deferred("_dispatch", key, envelope, listeners, use_envelope)
    else:
        _dispatch(key, envelope, listeners, use_envelope)

func _dispatch(key: StringName, envelope: Dictionary, listeners: Array, use_envelope: bool) -> void:
    var pruned := false
    for cb in listeners:
        if not cb or not cb.is_valid():
            pruned = true
            continue
        var err := OK
        if use_envelope:
            err = cb.call(envelope)
        else:
            err = cb.call(envelope["payload"])
        if typeof(err) == TYPE_INT and err != OK:
            push_warning("EventBus: handler error on topic %s err %s" % [key, err])
    if pruned:
        # remove invalids from the stored list
        var current: Array = _subs.get(key, [])
        # rebuild with only valid callables
        var cleaned := []
        for c in current:
            if c and c.is_valid():
                cleaned.append(c)
        if cleaned.is_empty():
            _subs.erase(key)
        else:
            _subs[key] = cleaned
