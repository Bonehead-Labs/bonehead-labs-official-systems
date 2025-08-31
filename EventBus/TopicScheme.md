# Topic Scheme - Guidline

## Quick Summary
The topic scheme is the naming convention for Event Bus messages.
Defines how events are categorised and identified, ensuring they are
- easy to filter and subscribe to
- easy to reason about as project scales up
- consistent across all systems and modules

## Conceptual Guide to 'Subscribing' and 'Filtering'
**Subscribing**
When subscribing to an event, it is analagous to "Hey EventBus, call this function if this type of event happens"
Example:
```
EventBus.sub("combat/damage", _on_damage_received)
```

Now whenever "combat/damage" is published, your _on_damage_received() function is called.

**Filtering**
Filtering means only listing to the events you care about.
Subscribe to specific topics like "ui/toast" or "scene/change" instead of catching everything.
Dev tools (like an EventBus inspector) may subscribe to all and filter in code:
```
if topic.begins_with("combat/"):
    print("Combat event:", topic)
```
## Format
```
<domain>/<action>
```
Examples:

ui/open → when a UI screen should be opened
player/jump → when a player has jumped
combat/damage → when damage is applied
save/requested → when something wants to trigger a save
enemy/died → when an enemy has been defeated
audio/volume_changed → when a volume slider is changed

##Data Type

Topics should be stored and compared as StringName, not raw strings.

### Why?

- StringName is faster to compare (internally hashed)
- Godot uses it for signal names, node paths, and input actions
- Prevents bugs caused by typos or inconsistent formatting

***How to use it:***
```
const COMBAT_DAMAGE := &"combat/damage"
EventBus.sub(COMBAT_DAMAGE, _on_damage_received)
```

The &"..." syntax is a shortcut for StringName("...") in GDScript 4.

## Reserved Domains

Use these as standard topic prefixes across systems:

| Prefix       | Used for                         |
|--------------|----------------------------------|
| `ui/`        | UI screen actions, prompts, toasts |
| `player/`    | Player-related events             |
| `enemy/`     | Enemy spawn, perception, death    |
| `combat/`    | Damage, healing, knockback        |
| `scene/`     | Scene transitions, checkpoints     |
| `save/`      | Save/load operations              |
| `items/`     | Inventory, pickups, crafting      |
| `audio/`     | Music, SFX, volume events         |
| `world/`     | Interactables, levers, hazards    |
| `debug/`     | Dev-only events (logging, metrics)|


# Best Practices
- Always use StringName (&"topic/name") when publishing and subscribing
- Keep topics coarse but meaningful — don’t fire 10 micro-events for one action
- Avoid game-specific terms like big_guy_died — use general ones like enemy/died with payload detail
- Standardize topic names across all systems to keep code traceable
- Enable Strict Mode in dev to catch unknown or typoed topics
