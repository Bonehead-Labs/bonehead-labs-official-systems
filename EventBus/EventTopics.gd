# res://core/events/EventTopics.gd
# Godot 4.x
class_name _EventTopics extends Node

# ───────────────────────────────────────────────────────────────────────────────
# INPUT (actions, axes, devices, rebinding)
# ───────────────────────────────────────────────────────────────────────────────
const INPUT_ACTION             : StringName = &"input/action"             # {action, edge:"pressed"|"released", device, ts}
const INPUT_AXIS               : StringName = &"input/axis"               # {axis, value, device, ts}
const INPUT_REBIND_STARTED     : StringName = &"input/rebind_started"     # {action}
const INPUT_REBIND_FINISHED    : StringName = &"input/rebind_finished"    # {action}
const INPUT_REBIND_FAILED      : StringName = &"input/rebind_failed"      # {action, reason}
const INPUT_DEVICE_CHANGED     : StringName = &"input/device_changed"     # {device_id, connected, kind}

# ───────────────────────────────────────────────────────────────────────────────
# UI (screen actions, prompts, toasts)
# ───────────────────────────────────────────────────────────────────────────────
const UI_TOAST                : StringName = &"ui/toast"                 # {text, kind?, duration?}
const UI_PROMPT_OPEN          : StringName = &"ui/prompt_open"           # {id, text, options?}
const UI_PROMPT_CHOICE        : StringName = &"ui/prompt_choice"         # {id, choice}
const UI_MODAL_OPEN           : StringName = &"ui/modal_open"            # {id}
const UI_MODAL_CLOSE          : StringName = &"ui/modal_close"           # {id}
const UI_SCREEN_PUSHED        : StringName = &"ui/screen_pushed"         # {id}
const UI_SCREEN_POPPED        : StringName = &"ui/screen_popped"         # {id}
const UI_TEMPLATE_EVENT       : StringName = &"ui/template_event"        # {template_id, event_id, payload}
const UI_HUD_SHOW             : StringName = &"ui/hud_show"              # {}
const UI_HUD_HIDE             : StringName = &"ui/hud_hide"              # {}
const UI_OBJECTIVE_UPDATE     : StringName = &"ui/objective_update"      # {text, state?}
const UI_TOOLTIP_SHOW         : StringName = &"ui/tooltip_show"          # {text, anchor?}
const UI_TOOLTIP_HIDE         : StringName = &"ui/tooltip_hide"          # {}

# ───────────────────────────────────────────────────────────────────────────────
# SCENE FLOW (scene stack + transitions)
# ───────────────────────────────────────────────────────────────────────────────
const FLOW_SCENE_PUSHED       : StringName = &"flow/scene_pushed"        # {scene_path, from?, stack_size, metadata?}
const FLOW_SCENE_REPLACED     : StringName = &"flow/scene_replaced"      # {scene_path, from?, stack_size, metadata?}
const FLOW_SCENE_POPPED       : StringName = &"flow/scene_popped"        # {scene_path, to?, stack_size, metadata?}
const FLOW_SCENE_ERROR        : StringName = &"flow/scene_error"         # {scene_path, code, message}
const FLOW_LOADING_STARTED    : StringName = &"flow/loading_started"     # {scene_path, operation, seed?, metadata?}
const FLOW_LOADING_PROGRESS   : StringName = &"flow/loading_progress"    # {scene_path, progress, operation, metadata?}
const FLOW_LOADING_COMPLETED  : StringName = &"flow/loading_completed"   # {scene_path, operation, duration_ms?, metadata?}
const FLOW_LOADING_FAILED     : StringName = &"flow/loading_failed"      # {scene_path, operation, error, metadata?}
const FLOW_LOADING_CANCELLED  : StringName = &"flow/loading_cancelled"   # {scene_path, operation}
const FLOW_TRANSITION_COMPLETED : StringName = &"flow/transition_completed" # {scene_path, transition_name, direction, metadata?}

# ───────────────────────────────────────────────────────────────────────────────
# PLAYER (player-related events)
# ───────────────────────────────────────────────────────────────────────────────
const PLAYER_SPAWNED          : StringName = &"player/spawned"           # {pos?, id?}
const PLAYER_DESPAWNED        : StringName = &"player/despawned"         # {id?}
const PLAYER_DAMAGED          : StringName = &"player/damaged"           # {amount, hp_after, source?}
const PLAYER_HEALED           : StringName = &"player/healed"            # {amount, hp_after, source?}
const PLAYER_DIED             : StringName = &"player/died"              # {source?}
const PLAYER_RESPAWNED        : StringName = &"player/respawned"         # {pos?}
const PLAYER_MOVED            : StringName = &"player/moved"             # {pos, vel?}
const PLAYER_JUMPED           : StringName = &"player/jumped"            # {strength?}
const PLAYER_LANDED           : StringName = &"player/landed"            # {hard?:bool}
const PLAYER_STATE_CHANGED    : StringName = &"player/state_changed"     # {from, to}
const PLAYER_STATUS_EFFECT    : StringName = &"player/status_effect"     # {effect, add?:bool, duration?}
const PLAYER_ITEM_PICKUP      : StringName = &"player/item_pickup"       # {item_id, qty?, source?}
const PLAYER_ITEM_USED        : StringName = &"player/item_used"         # {item_id, result?}
const PLAYER_STAMINA_CHANGED  : StringName = &"player/stamina_changed"   # {value, max?}
const PLAYER_MANA_CHANGED     : StringName = &"player/mana_changed"      # {value, max?}
const PLAYER_INTERACTION_DETECTED : StringName = &"player/interaction_detected" # {interactable_type, interactable_name, distance}
const PLAYER_INTERACTION_LOST : StringName = &"player/interaction_lost" # {interactable_type, interactable_name}
const PLAYER_INTERACTION_EXECUTED : StringName = &"player/interaction_executed" # {interactable_type, interactable_name, interaction_position}
const PLAYER_ABILITY_STARTED  : StringName = &"player/ability_started"  # {ability_id, metadata?}
const PLAYER_ABILITY_ENDED    : StringName = &"player/ability_ended"    # {ability_id, metadata?}
const PLAYER_ABILITY_FAILED   : StringName = &"player/ability_failed"   # {ability_id, reason, details?}
const PLAYER_ABILITY_USED     : StringName = &"player/ability_used"      # {ability_type, ability_id, data?}

# Combat System Events
const COMBAT_HURTBOX_HIT      : StringName = &"combat/hurtbox_hit"       # {hurtbox_faction, hitbox_faction, damage_amount, damage_type, source_type, hurtbox_position, hitbox_position, timestamp_ms}
const COMBAT_HITBOX_ACTIVATED : StringName = &"combat/hitbox_activated"  # {hitbox_faction, damage_amount, damage_type, hitbox_position, timestamp_ms}
const COMBAT_HITBOX_DEACTIVATED : StringName = &"combat/hitbox_deactivated" # {hitbox_faction, hitbox_position, timestamp_ms}
const COMBAT_ENTITY_DEATH     : StringName = &"combat/entity_death"      # {entity_name, entity_type, faction, position, damage_source, damage_type, timestamp_ms}

# Faction System Events
const FACTION_REGISTERED       : StringName = &"faction/registered"       # {faction, timestamp_ms}
const FACTION_UNREGISTERED     : StringName = &"faction/unregistered"     # {faction, timestamp_ms}
const FACTION_RELATIONSHIP_CHANGED : StringName = &"faction/relationship_changed" # {faction_a, faction_b, relationship, timestamp_ms}

# Enemy AI Events
const ENEMY_SPAWNED           : StringName = &"enemy/spawned"            # {enemy_type, enemy_name, faction, position, config, timestamp_ms}
const ENEMY_ALERTED           : StringName = &"enemy/alerted"            # {enemy_type, enemy_name, faction, target, position, timestamp_ms}
const ENEMY_DEFEATED          : StringName = &"enemy/defeated"           # {enemy_type, enemy_name, faction, cause, damage_source, final_health, position, timestamp_ms}
const ENEMY_STATE_CHANGED     : StringName = &"enemy/state_changed"      # {enemy_type, enemy_name, faction, old_state, new_state, timestamp_ms}
const ENEMY_SPAWNED_FROM_SPAWNER : StringName = &"enemy/spawned_from_spawner" # {spawner, enemy_type, position}
const ENEMY_ATTACK_START      : StringName = &"enemy/attack_start"       # {enemy, attack_type}
const ENEMY_ATTACK_END        : StringName = &"enemy/attack_end"         # {enemy, attack_type}

# ───────────────────────────────────────────────────────────────────────────────
# ENEMY (spawn, perception, death)
# ───────────────────────────────────────────────────────────────────────────────
const ENEMY_DESPAWNED         : StringName = &"enemy/despawned"          # {id}
const ENEMY_PERCEIVED_PLAYER  : StringName = &"enemy/perceived_player"   # {id, kind:"sight"|"sound", pos?}
const ENEMY_LOST_PLAYER       : StringName = &"enemy/lost_player"        # {id}
const ENEMY_DAMAGED           : StringName = &"enemy/damaged"            # {id, amount, hp_after, source?}
const ENEMY_DIED              : StringName = &"enemy/died"               # {id, source?}
const ENEMY_ATTACK_STARTED    : StringName = &"enemy/attack_started"     # {id, attack?}
const ENEMY_ATTACK_LANDED     : StringName = &"enemy/attack_landed"      # {id, amount, target?}

# ───────────────────────────────────────────────────────────────────────────────
# COMBAT (damage, healing, knockback)
# ───────────────────────────────────────────────────────────────────────────────
const COMBAT_HIT              : StringName = &"combat/hit"               # {attacker?, target?, amount, crit?:bool}
const COMBAT_BLOCKED          : StringName = &"combat/blocked"           # {attacker?, target?}
const COMBAT_PARRIED          : StringName = &"combat/parried"           # {attacker?, target?}
const COMBAT_HEAL             : StringName = &"combat/heal"              # {healer?, target?, amount}
const COMBAT_KNOCKBACK        : StringName = &"combat/knockback"         # {target, force:Vector2}
const COMBAT_STATUS_APPLIED   : StringName = &"combat/status_applied"    # {target, effect, duration}
const COMBAT_STATUS_EXPIRED   : StringName = &"combat/status_expired"    # {target, effect}
const COMBAT_WEAPON_SWAPPED   : StringName = &"combat/weapon_swapped"    # {owner, from, to}
const COMBAT_PROJECTILE_FIRED : StringName = &"combat/projectile_fired"  # {owner, proj_id, dir, speed}
const COMBAT_PROJECTILE_HIT   : StringName = &"combat/projectile_hit"    # {proj_id, target?, amount?}

# ───────────────────────────────────────────────────────────────────────────────
# SCENE (transitions, checkpoints)
# ───────────────────────────────────────────────────────────────────────────────
const SCENE_WILL_CHANGE       : StringName = &"scene/will_change"        # {from, to}
const SCENE_DID_CHANGE        : StringName = &"scene/did_change"         # {from, to}
const SCENE_RELOADED          : StringName = &"scene/reloaded"           # {id?}
const SCENE_CHECKPOINT_REACHED: StringName = &"scene/checkpoint_reached" # {id, pos?}
const SCENE_PAUSED            : StringName = &"scene/paused"             # {}
const SCENE_RESUMED           : StringName = &"scene/resumed"            # {}

# ───────────────────────────────────────────────────────────────────────────────
# SAVE (save/load operations)
# ───────────────────────────────────────────────────────────────────────────────
const SAVE_REQUEST            : StringName = &"save/request"             # {slot?, reason?}
const SAVE_COMPLETED          : StringName = &"save/completed"           # {slot?, ok:bool}
const LOAD_REQUEST            : StringName = &"save/load_request"        # {slot?}
const LOAD_COMPLETED          : StringName = &"save/load_completed"      # {slot?, ok:bool}
const SAVE_QUICK              : StringName = &"save/quick"               # {}
const LOAD_QUICK              : StringName = &"save/load_quick"          # {}

# ───────────────────────────────────────────────────────────────────────────────
# ITEMS (inventory, pickups, crafting)
# ───────────────────────────────────────────────────────────────────────────────
const ITEMS_ADDED             : StringName = &"items/added"              # {entries:[{item_id, qty}], owner?}
const ITEMS_REMOVED           : StringName = &"items/removed"            # {entries:[{item_id, qty}], owner?}
const ITEMS_EQUIPPED          : StringName = &"items/equipped"           # {slot, item_id}
const ITEMS_UNEQUIPPED        : StringName = &"items/unequipped"         # {slot, item_id}
const ITEMS_CRAFT_REQUEST     : StringName = &"items/craft_request"      # {recipe_id}
const ITEMS_CRAFTED           : StringName = &"items/crafted"            # {item_id, qty}
const ITEMS_CONSUMED          : StringName = &"items/consumed"           # {item_id, qty, owner?}
const ITEMS_HOTBAR_CHANGED    : StringName = &"items/hotbar_changed"     # {index, item_id?}
const ITEMS_PICKED_UP         : StringName = &"item/picked_up"           # {item_id, quantity, by}
const SHOP_PURCHASED          : StringName = &"shop/purchased"           # {buyer, item_id, price}

# ───────────────────────────────────────────────────────────────────────────────
# AUDIO (music, SFX, volume)
# ───────────────────────────────────────────────────────────────────────────────
const AUDIO_MUSIC_PLAY        : StringName = &"audio/music_play"         # {track, loop?:bool}
const AUDIO_MUSIC_STOP        : StringName = &"audio/music_stop"         # {}
const AUDIO_MUSIC_FADE        : StringName = &"audio/music_fade"         # {to_db, duration}
const AUDIO_SFX_PLAY          : StringName = &"audio/sfx_play"           # {id, pos?, vol_db?}
const AUDIO_VOLUME_SET        : StringName = &"audio/volume_set"         # {bus:"Master"|"Music"|"SFX", db}
const AUDIO_MUTE_SET          : StringName = &"audio/mute_set"           # {bus, mute:bool}

# ───────────────────────────────────────────────────────────────────────────────
# WORLD (interactables, levers, hazards)
# ───────────────────────────────────────────────────────────────────────────────
const WORLD_INTERACT          : StringName = &"world/interact"           # {who, target}
const WORLD_LEVER_TOGGLED     : StringName = &"world/lever_toggled"      # {id, on:bool}
const WORLD_BUTTON_PRESSED    : StringName = &"world/button_pressed"     # {id}
const WORLD_DOOR_OPENED       : StringName = &"world/door_opened"        # {id}
const WORLD_DOOR_CLOSED       : StringName = &"world/door_closed"        # {id}
const WORLD_HAZARD_TRIGGERED  : StringName = &"world/hazard_triggered"   # {id, who?, amount?}
const WORLD_CHECKPOINT_SET    : StringName = &"world/checkpoint_set"     # {id, pos}
const WORLD_TIME_OF_DAY       : StringName = &"world/time_of_day"        # {phase}
const WORLD_WEATHER_CHANGED   : StringName = &"world/weather_changed"    # {from, to}
const WORLD_PORTAL_USED       : StringName = &"world/portal_used"        # {portal, body, target_scene, target_spawn}
const WORLD_TIME_PAUSED       : StringName = &"world/time_paused"        # {}
const WORLD_TIME_RESUMED      : StringName = &"world/time_resumed"       # {}
const WORLD_TIME_SCALE_CHANGED : StringName = &"world/time_scale_changed" # {scale}
const WORLD_PROP_DAMAGED      : StringName = &"world/prop_damaged"       # {prop, amount, source?}
const WORLD_PROP_DESTROYED    : StringName = &"world/prop_destroyed"     # {prop, source?}
const WORLD_PROP_RESPAWNED    : StringName = &"world/prop_respawned"     # {prop}
const WORLD_HAZARD_ENTERED    : StringName = &"world/hazard_entered"     # {hazard, body}
const WORLD_HAZARD_EXITED     : StringName = &"world/hazard_exited"      # {hazard, body}
const WORLD_HAZARD_DAMAGE     : StringName = &"world/hazard_damage"      # {hazard, body, amount}
const WORLD_LEVEL_LOAD_STARTED : StringName = &"world/level_load_started" # {scene_path, payload_keys}
const WORLD_LEVEL_LOAD_FAILED : StringName = &"world/level_load_failed"  # {scene_path, reason}
const WORLD_LEVEL_LOAD_SUCCESS : StringName = &"world/level_load_success" # {scene_path, payload_keys}
const WORLD_LEVEL_PUSH_STARTED : StringName = &"world/level_push_started" # {scene_path, payload_keys}
const WORLD_LEVEL_PUSH_FAILED : StringName = &"world/level_push_failed"  # {scene_path, reason}
const WORLD_LEVEL_PUSH_SUCCESS : StringName = &"world/level_push_success" # {scene_path, payload_keys}
const WORLD_LEVEL_POP_STARTED : StringName = &"world/level_pop_started"  # {}
const WORLD_LEVEL_POP_FAILED  : StringName = &"world/level_pop_failed"   # {reason}
const WORLD_LEVEL_POP_SUCCESS : StringName = &"world/level_pop_success"  # {}
const WORLD_CHECKPOINT_REGISTERED : StringName = &"world/checkpoint_registered" # {checkpoint}
const WORLD_CHECKPOINT_ACTIVATED : StringName = &"world/checkpoint_activated" # {checkpoint}
const WORLD_INTERACTED        : StringName = &"world/interacted"         # {interactable, interactor}

# ───────────────────────────────────────────────────────────────────────────────
# DEBUG (dev-only: logging, metrics)
# ───────────────────────────────────────────────────────────────────────────────
const DEBUG_LOG               : StringName = &"debug/log"                # {msg, level?}
const DEBUG_METRIC            : StringName = &"debug/metric"             # {name, value, tags?}
const DEBUG_WATCH_TOPIC       : StringName = &"debug/watch_topic"        # {topic, on:bool}
const DEBUG_LISTENERS_DUMP    : StringName = &"debug/listeners_dump"     # {}
const DEBUG_CRASH_DETECTED    : StringName = &"debug/crash_detected"     # {error, scene, stack}
const DEBUG_WARNING           : StringName = &"debug/warning"            # {msg, source?}
const DEBUG_ERROR             : StringName = &"debug/error"              # {msg, source?}

# ───────────────────────────────────────────────────────────────────────────────
# Optional: registry for validation / tooling in dev builds
# ───────────────────────────────────────────────────────────────────────────────
static var ALL : Array[StringName] = [
    # input
    INPUT_ACTION, INPUT_AXIS, INPUT_REBIND_STARTED, INPUT_REBIND_FINISHED,
    INPUT_REBIND_FAILED, INPUT_DEVICE_CHANGED,

    # ui
    UI_TOAST, UI_PROMPT_OPEN, UI_PROMPT_CHOICE, UI_MODAL_OPEN, UI_MODAL_CLOSE,
    UI_SCREEN_PUSHED, UI_SCREEN_POPPED, UI_HUD_SHOW, UI_HUD_HIDE,
    UI_OBJECTIVE_UPDATE, UI_TOOLTIP_SHOW, UI_TOOLTIP_HIDE,

    # scene flow
    FLOW_SCENE_PUSHED, FLOW_SCENE_REPLACED, FLOW_SCENE_POPPED, FLOW_SCENE_ERROR,
    FLOW_LOADING_STARTED, FLOW_LOADING_PROGRESS, FLOW_LOADING_COMPLETED,
    FLOW_LOADING_FAILED, FLOW_LOADING_CANCELLED, FLOW_TRANSITION_COMPLETED,

    # player
    PLAYER_SPAWNED, PLAYER_DESPAWNED, PLAYER_DAMAGED, PLAYER_HEALED, PLAYER_DIED,
    PLAYER_RESPAWNED, PLAYER_MOVED, PLAYER_JUMPED, PLAYER_LANDED,
    PLAYER_STATE_CHANGED, PLAYER_STATUS_EFFECT, PLAYER_ITEM_PICKUP,
    PLAYER_ITEM_USED, PLAYER_STAMINA_CHANGED, PLAYER_MANA_CHANGED,
    PLAYER_INTERACTION_DETECTED, PLAYER_INTERACTION_LOST, PLAYER_INTERACTION_EXECUTED,
    PLAYER_ABILITY_STARTED, PLAYER_ABILITY_ENDED, PLAYER_ABILITY_FAILED, PLAYER_ABILITY_USED,

    # enemy
    ENEMY_SPAWNED, ENEMY_ALERTED, ENEMY_DEFEATED, ENEMY_STATE_CHANGED,
    ENEMY_DESPAWNED, ENEMY_PERCEIVED_PLAYER, ENEMY_LOST_PLAYER,
    ENEMY_DAMAGED, ENEMY_DIED, ENEMY_ATTACK_STARTED, ENEMY_ATTACK_LANDED,
    ENEMY_SPAWNED_FROM_SPAWNER, ENEMY_ATTACK_START, ENEMY_ATTACK_END,

    # combat
    COMBAT_HIT, COMBAT_BLOCKED, COMBAT_PARRIED, COMBAT_HEAL, COMBAT_KNOCKBACK,
    COMBAT_STATUS_APPLIED, COMBAT_STATUS_EXPIRED, COMBAT_WEAPON_SWAPPED,
    COMBAT_PROJECTILE_FIRED, COMBAT_PROJECTILE_HIT, COMBAT_HURTBOX_HIT,
    COMBAT_HITBOX_ACTIVATED, COMBAT_HITBOX_DEACTIVATED, COMBAT_ENTITY_DEATH,
    FACTION_REGISTERED, FACTION_UNREGISTERED, FACTION_RELATIONSHIP_CHANGED,

    # scene
    SCENE_WILL_CHANGE, SCENE_DID_CHANGE, SCENE_RELOADED, SCENE_CHECKPOINT_REACHED,
    SCENE_PAUSED, SCENE_RESUMED,

    # save
    SAVE_REQUEST, SAVE_COMPLETED, LOAD_REQUEST, LOAD_COMPLETED, SAVE_QUICK, LOAD_QUICK,

    # items
    ITEMS_ADDED, ITEMS_REMOVED, ITEMS_EQUIPPED, ITEMS_UNEQUIPPED, ITEMS_CRAFT_REQUEST,
    ITEMS_CRAFTED, ITEMS_CONSUMED, ITEMS_HOTBAR_CHANGED, ITEMS_PICKED_UP, SHOP_PURCHASED,

    # audio
    AUDIO_MUSIC_PLAY, AUDIO_MUSIC_STOP, AUDIO_MUSIC_FADE, AUDIO_SFX_PLAY,
    AUDIO_VOLUME_SET, AUDIO_MUTE_SET,

    # world
    WORLD_INTERACT, WORLD_LEVER_TOGGLED, WORLD_BUTTON_PRESSED, WORLD_DOOR_OPENED,
    WORLD_DOOR_CLOSED, WORLD_HAZARD_TRIGGERED, WORLD_CHECKPOINT_SET, WORLD_TIME_OF_DAY,
    WORLD_WEATHER_CHANGED, WORLD_PORTAL_USED, WORLD_TIME_PAUSED, WORLD_TIME_RESUMED,
    WORLD_TIME_SCALE_CHANGED, WORLD_PROP_DAMAGED, WORLD_PROP_DESTROYED, WORLD_PROP_RESPAWNED,
    WORLD_HAZARD_ENTERED, WORLD_HAZARD_EXITED, WORLD_HAZARD_DAMAGE, WORLD_LEVEL_LOAD_STARTED,
    WORLD_LEVEL_LOAD_FAILED, WORLD_LEVEL_LOAD_SUCCESS, WORLD_LEVEL_PUSH_STARTED,
    WORLD_LEVEL_PUSH_FAILED, WORLD_LEVEL_PUSH_SUCCESS, WORLD_LEVEL_POP_STARTED,
    WORLD_LEVEL_POP_FAILED, WORLD_LEVEL_POP_SUCCESS, WORLD_CHECKPOINT_REGISTERED,
    WORLD_CHECKPOINT_ACTIVATED, WORLD_INTERACTED,

    # debug
    DEBUG_LOG, DEBUG_METRIC, DEBUG_WATCH_TOPIC, DEBUG_LISTENERS_DUMP,
    DEBUG_CRASH_DETECTED, DEBUG_WARNING, DEBUG_ERROR
]

## Validates if a topic is registered in the EventTopics registry
## 
## [b]topic:[/b] The topic to validate
## 
## [b]Returns:[/b] true if the topic exists in the registry
static func is_valid(topic: StringName) -> bool:
    return ALL.has(topic)
