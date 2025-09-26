extends Control

var received_contexts: Array = []
var entered_count: int = 0
var exited_count: int = 0

## Receive context data from screen manager
## 
## Called when the screen receives context data during navigation.
## Stores a deep copy of the context for testing purposes.
## 
## [b]context:[/b] Context data dictionary
func receive_context(context: Dictionary[StringName, Variant]) -> void:
    received_contexts.append(context.duplicate(true))

## Handle screen entry lifecycle event
## 
## Called when the screen becomes active and visible.
## Increments the entry counter for testing purposes.
## 
## [b]_context:[/b] Context data (unused)
func on_screen_entered(_context: Dictionary[StringName, Variant]) -> void:
    entered_count += 1

## Handle screen exit lifecycle event
## 
## Called when the screen becomes inactive and hidden.
## Increments the exit counter for testing purposes.
## 
## [b]_context:[/b] Context data (unused)
func on_screen_exited(_context: Dictionary[StringName, Variant]) -> void:
    exited_count += 1
