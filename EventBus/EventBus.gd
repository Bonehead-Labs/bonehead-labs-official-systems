class_name EventBus

var _subs: Dictionary = {} #Dictionary[StringName, Array[Callable]]


# Subscribe to an event
func sub(topic: StringName, cb: Callable) -> void:
    var key = StringName(topic)
    if not _subs.has(key):
        _subs[key] = []
    _subs[key].append(cb)


func unsub(topic: StringName, cb: Callable) -> void:
    var key := StringName(topic)
    if not _subs.has(key):
        return
    _subs[key].erase(cb)
    if _subs[key].is_empty():
        _subs.erase(key)


func pub(topic: StringName, payload: Dictionary) -> void:
    var key := StringName(topic)
    if not _subs.has(key):
        return
    var listeners: Array = _subs[key].duplicate()
    for cb in listeners:
        if not cb or not cb.is_valid():
            continue
        var err := OK
        err = cb.call(payload)
        if typeof(err) == TYPE_INT and err != OK:
            print("EventBus: handler returned error on topic: ", key, " err: ", err)


