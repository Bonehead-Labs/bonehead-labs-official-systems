class_name _EventBus extends Node

# Event subscription storage: topic -> array of callables
var _subs: Dictionary = {} # Dictionary[StringName, Array[Callable]]
# Catch-all subscribers that receive all events
var _catch_all: Array[Callable] = []
# If true, events are dispatched on the next frame for safety
var deferred_mode: bool = false
# If true, validates topics against EventTopics registry
var strict_mode: bool = false

## Validates topic against EventTopics registry if strict mode is enabled
## 
## [b]topic:[/b] The topic to validate
## 
## [b]Returns:[/b] true if topic is valid or strict mode is disabled
func _validate_topic(topic: StringName) -> bool:
	if not strict_mode:
		return true
	if not _EventTopics.is_valid(topic):
		push_error("EventBus: invalid topic '%s'" % [topic])
		return false
	return true

## Subscribe to a specific event topic
## 
## [b]topic:[/b] The event topic to subscribe to
## [b]cb:[/b] Callable to invoke when the event is published
func sub(topic: StringName, cb: Callable) -> void:
	if not _validate_topic(topic):
		return
	var key := StringName(topic)
	var arr: Array = _subs.get(key, [])
	if not arr.has(cb):
		arr.append(cb)
	_subs[key] = arr

## Unsubscribe from a specific event topic
## 
## [b]topic:[/b] The event topic to unsubscribe from
## [b]cb:[/b] Callable to remove from subscriptions
func unsub(topic: StringName, cb: Callable) -> void:
	var key := StringName(topic)
	if not _subs.has(key):
		return
	_subs[key].erase(cb)
	if _subs[key].is_empty():
		_subs.erase(key)

## Publish an event to all subscribers
## 
## [b]topic:[/b] The event topic to publish
## [b]payload:[/b] Data to send with the event
## [b]use_envelope:[/b] If true, subscribers receive full envelope; if false, just payload
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

## Subscribe to all events (catch-all subscription)
## 
## [b]cb:[/b] Callable to invoke for every published event
func sub_all(cb: Callable) -> void:
	if not _catch_all.has(cb):
		_catch_all.append(cb)

## Unsubscribe from all events (catch-all subscription)
## 
## [b]cb:[/b] Callable to remove from catch-all subscriptions
func unsub_all(cb: Callable) -> void:
	_catch_all.erase(cb)

## Dispatch event to all catch-all subscribers
## 
## [b]envelope:[/b] Event envelope containing topic, payload, timestamp, and frame
func _dispatch_catch_all(envelope: Dictionary) -> void:
	var pruned := false
	for cb in _catch_all.duplicate():
		if cb == null or not cb.is_valid():
			pruned = true
			continue
		var result: Variant = cb.call(envelope)
		if typeof(result) == TYPE_INT and result != OK:
			push_warning("EventBus: handler error on catch all err %s" % [result])
	
	if pruned:
		_cleanup_catch_all_invalid_callables()

## Clean up invalid callables from catch-all subscriptions
func _cleanup_catch_all_invalid_callables() -> void:
	var cleaned := []
	for c in _catch_all:
		if c != null and c.is_valid():
			cleaned.append(c)
	_catch_all = cleaned

## Dispatch event to topic-specific subscribers
## 
## [b]key:[/b] The event topic key
## [b]envelope:[/b] Event envelope containing topic, payload, timestamp, and frame
## [b]listeners:[/b] Array of callables subscribed to this topic
## [b]use_envelope:[/b] If true, pass full envelope; if false, pass just payload
func _dispatch(key: StringName, envelope: Dictionary, listeners: Array, use_envelope: bool) -> void:
	var pruned := false
	for cb in listeners:
		if cb == null or not cb.is_valid():
			pruned = true
			continue
		var result: Variant = cb.call(envelope if use_envelope else envelope["payload"])
		if typeof(result) == TYPE_INT and result != OK:
			push_warning("EventBus: handler error on topic %s err %s" % [key, result])
	
	_dispatch_catch_all(envelope)  # <- use the helper

	if pruned:
		_cleanup_invalid_callables(key)

## Clean up invalid callables from a topic's subscription list
## 
## [b]key:[/b] The topic key to clean up
func _cleanup_invalid_callables(key: StringName) -> void:
	var current: Array = _subs.get(key, [])
	var cleaned := []
	for c in current:
		if c != null and c.is_valid():
			cleaned.append(c)
	if cleaned.is_empty():
		_subs.erase(key)
	else:
		_subs[key] = cleaned
