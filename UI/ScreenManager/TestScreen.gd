extends Control

var received_contexts: Array = []
var entered_count: int = 0
var exited_count: int = 0

func receive_context(context: Dictionary[StringName, Variant]) -> void:
    received_contexts.append(context.duplicate(true))

func on_screen_entered(_context: Dictionary[StringName, Variant]) -> void:
    entered_count += 1

func on_screen_exited(_context: Dictionary[StringName, Variant]) -> void:
    exited_count += 1
