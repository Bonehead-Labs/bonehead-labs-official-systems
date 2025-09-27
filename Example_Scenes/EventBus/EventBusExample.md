# Event Bus Example - Wiring Cross-System Messaging

This example shows how to build a lightweight messaging layer that lets systems broadcast and react to events without tight coupling. The demo scene walks through subscribing to topics, publishing structured payloads, and monitoring traffic with tooling.

## High-Level Concept

The EventBus provides a global publish/subscribe hub. Code that produces events only names a topic and payload; listeners decide whether to care. This mirrors message buses in large systems and keeps modules decoupled.

### Key Benefits:
- **Loose Coupling**: Publishers never reach directly into listeners
- **Discoverable Traffic**: Topics create a shared vocabulary
- **Inspector-Friendly**: Works with the EventBusInspector for runtime debugging
- **Pluggable**: Any script can opt in to send or receive events on demand

## Architecture Overview

```
EventBus (autoload singleton)
├── Topic Registry (EventTopics.gd)
├── Subscribers (Callable lists per topic)
└── Catch-All Listeners (optional diagnostics)
```

The bus manages:
- Validating topics (strict mode) against `EventTopics`
- Dispatching events immediately or deferred
- Delivering payload-only or full envelopes
- Cleaning up invalid callables automatically

## Implementation Guide

### Step 1: Autoload the EventBus

1. Add `EventBus/EventBus.gd` as an autoload singleton (Project Settings → Autoload).
2. Add `EventBus/EventTopics.gd` as a helper to share topic constants.
3. Optional: expose `EventBusInspector` if you want an in-engine monitor.

```gdscript
# project.godot
[autoload]
EventBus="res://EventBus/EventBus.gd"
EventTopics="res://EventBus/EventTopics.gd"
```

### Step 2: Define Topics

Centralize topic names to avoid typos and keep everything `StringName`-based.

```gdscript
# EventBus/EventTopics.gd
class_name EventTopics

const INPUT_ACTION := &"input/action"
const DEBUG_LOG := &"debug/log"
const DEMO_STARTUP := &"demo/startup"  # Only for sandbox demos
```

Throughout the project import and reuse these identifiers.

### Step 3: Publish Events

Publishing broadcasts a topic and optional payload. In the demo the button emits a debug log event.

```gdscript
EventBus.pub(EventTopics.DEBUG_LOG, {
    "msg": "Demo button pressed",
    "level": "INFO",
    "source": "EventBusDemo"
})
```

Use envelopes when consumers need metadata (topic, timestamp, frame number):

```gdscript
EventBus.pub(EventTopics.DEBUG_LOG, payload, use_envelope := true)
```

### Step 4: Subscribe to Topics

Subscribe using callables. The demo tracks player actions and debug logs separately.

```gdscript
var _input_listener := Callable(self, "_on_input_action")
EventBus.sub(EventTopics.INPUT_ACTION, _input_listener)

func _on_input_action(payload: Dictionary) -> void:
    var action: StringName = payload.get("action", StringName())
    var edge := payload.get("edge", "")
    if action == StringName("jump") and edge == "pressed":
        _play_jump_feedback()
```

Always call `EventBus.unsub()` in `_exit_tree()` or teardown paths to prevent dangling references.

### Step 5: Catch-All Diagnostics (Optional)

Attach a callable with `sub_all()` to inspect every envelope. This powers the log viewer and inspector toggle in the demo.

```gdscript
var _catch_all := Callable(self, "_on_any_event")
EventBus.sub_all(_catch_all)

func _on_any_event(envelope: Dictionary) -> void:
    var topic: StringName = envelope.topic
    var payload: Dictionary = envelope.payload
    print("[BUS]", topic, JSON.stringify(payload))
```

When done, remove it with `EventBus.unsub_all(_catch_all)`.

### Step 6: Wire UI or Gameplay Responses

The example scene prints to a `RichTextLabel`, but in production you would:
- Trigger toasts or popups for `ui/` events
- Route combat events to HUD damage numbers
- Invoke audio cues from `audio/` topics

The same pattern scales from small demos to complex gameplay flows.

## Key Concepts Demonstrated

### Topic-Driven Contracts
- Topics describe *what* happened, not *who* cares
- Shared constants keep the vocabulary consistent
- Strict mode surfaces invalid or typoed topics immediately

### Envelope Payloads
- Metadata includes timestamp, topic, and frame to ease debugging
- Consumers choose payload-only vs full envelope delivery
- Catch-all listeners receive the whole envelope for inspection

### Lifecycle Safety
- Deferred dispatch avoids modifying data during iteration
- Automatic pruning protects against freed objects
- `unsub` guards against leaks when scenes exit

## Event Flow Pattern

```
InputService → EventBus.pub(input/action)
EventBus (dispatch) → Gameplay/Debug listeners
Catch-all → console log / inspector overlay
```

## Extending the Pattern

You can layer more systems on top of the bus without modifying existing code.

### Common Extensions
- **UI Notifications**: Publish `ui/toast` with `{text, kind}`
- **Scene Coordination**: Emit `scene/change` requests from triggers, handle in a central scene loader
- **Audio Hooks**: Map `audio/play` events to the AudioService
- **Analytics/Telemetry**: Catch-all subscriber forwards envelopes to analytics sinks

### Advanced Features
- **Strict Topic Validation**: Toggle `EventBus.strict_mode = true` during development
- **Deferred Mode**: Set `EventBus.deferred_mode = true` when publishing from physics or iteration-sensitive code
- **Inspector Integration**: Bind F4 (or another action) to show the EventBusInspector using a `debug_toggle_inspector` event

```gdscript
if Input.is_action_just_pressed("debug_toggle_inspector"):
    EventBus.pub(EventTopics.DEBUG_LOG, {"msg": "Inspector toggled"})
```

## Key Design Principles

1. **Decoupling**: Modules broadcast intent instead of calling each other directly
2. **Discoverability**: Shared topic registry documents available events
3. **Fault Isolation**: Handlers failing return warnings without crashing publishers
4. **Scalability**: Catch-all listeners and tooling help reason about large event graphs
5. **Consistency**: StringName topics enforce naming discipline across teams

## Troubleshooting

- **No events received**: Confirm the topic constant matches and listener is valid
- **Strict mode errors**: Register the topic in `EventTopics.gd` or disable strict mode temporarily
- **Catch-all spam**: Filter topics in your handler or detach the listener while profiling
- **Button shows nothing**: Ensure the demo scene runs with the EventBus autoloads present
- **Inspector not opening**: Check the input action (default F4 in demo) is bound inside `InputService`

## Summary

The EventBus demo illustrates how to decouple systems with publish/subscribe messaging. By standardizing topics, encapsulating payloads, and leveraging diagnostics tooling, you can expand your game’s feature set without entangling modules or rewriting core logic.
