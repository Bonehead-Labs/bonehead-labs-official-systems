class_name EventBus extends Node

var _subs: Dictionary = {} #Dictionary[StringName, Array[Callable]]
var _catch_all: Array[Callable] = []
var deferred_mode: bool = false
var strict_mode: bool = false

# Validate topic before subscribing or publishing
func _validate_topic(topic: StringName) -> bool:
	if not strict_mode:
		return true
	if not EventTopics.is_valid(topic):
		push_error("EventBus: invalid topic '%s'" % [topic])
		return false
	return true

# Subscribe to an event
func sub(topic: StringName, cb: Callable) -> void:
	if not _validate_topic(topic):
		return
	var key = StringName(topic)
	var arr: Array = _subs.get(key, [])
	if not arr.has(cb):
		arr.append(cb)
	_subs[key] = arr

# Unsubscribe from an event
func unsub(topic: StringName, cb: Callable) -> void:
	var key := StringName(topic)
	if not _subs.has(key):
		return
	_subs[key].erase(cb)
	if _subs[key].is_empty():
		_subs.erase(key)

# Publish an event
func pub(topic: StringName, payload: Dictionary = {}, use_envelope: bool = false) -> void:
	if not _validate_topic(topic):
		return
	var key := StringName(topic)
	var envelope: Dictionary = {
		"topic": key,
		"payload": payload,
		"timestamp_ms": Time.get_ticks_msec(),
		"frame": Engine.get_frames_drawn()
	}
	var listeners: Array = _subs.get(key, []).duplicate()
	if deferred_mode:
		# Schedule dispatch safely
		call_deferred("_dispatch", key, envelope, listeners, use_envelope)
	else:
		_dispatch(key, envelope, listeners, use_envelope)

# Subscribe to all events
func sub_all(cb: Callable) -> void:
	if not _catch_all.has(cb):
		_catch_all.append(cb)

# Unsubscribe from all events
func unsub_all(cb: Callable) -> void:
	_catch_all.erase(cb)

# Dispatch an event to all subscribers
func _dispatch_catch_all(envelope: Dictionary) -> void:
	var pruned := false
	for cb in _catch_all.duplicate():
		if not cb or not cb.is_valid():
			pruned = true
			continue
		var err = cb.call(envelope)
		if typeof(err) == TYPE_INT and err != OK:
			push_warning("EventBus: handler error on catch all err %s" % [err])
	
	if pruned:
		_cleanup_catch_all_invalid_callables()

# Clean up invalid callables from catch-all subscriptions
func _cleanup_catch_all_invalid_callables() -> void:
	var cleaned := []
	for c in _catch_all:
		if c and c.is_valid():
			cleaned.append(c)
	_catch_all = cleaned

# Dispatch an event
func _dispatch(key: StringName, envelope: Dictionary, listeners: Array, use_envelope: bool) -> void:
	var pruned := false
	for cb in listeners:
		if not cb or not cb.is_valid():
			pruned = true
			continue
		var err
		if use_envelope:
			err = cb.call(envelope)
		else:
			err = cb.call(envelope["payload"])
		if typeof(err) == TYPE_INT and err != OK:
			push_warning("EventBus: handler error on topic %s err %s" % [key, err])
	
	_dispatch_catch_all(envelope)  # <- use the helper

	if pruned:
		_cleanup_invalid_callables(key)

# Clean up invalid callables from a topic's subscription list
func _cleanup_invalid_callables(key: StringName) -> void:
	var current: Array = _subs.get(key, [])
	var cleaned := []
	for c in current:
		if c and c.is_valid():
			cleaned.append(c)
	if cleaned.is_empty():
		_subs.erase(key)
	else:
		_subs[key] = cleaned
