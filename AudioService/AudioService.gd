class_name _AudioService
extends Node

# ───────────────────────────────────────────────────────────────────────────────
# AudioService (Godot 4)
# Core systems: Bus/Mixer, Sound Library, SFX Pools, Music Crossfade,
# Ducking, Spatial Helpers, SaveService integration, Pause/Focus handling.
# Use as autoload: AudioService
# ───────────────────────────────────────────────────────────────────────────────

# Quick Start
# 1) Add this script as an autoload singleton named `AudioService`.
# 2) Register sounds (e.g., in a bootstrap scene):
#    AudioService.register_sound("click", load("res://audio/ui_click.ogg"), AudioService.BUS_UI, "UI")
#    AudioService.register_sound("explosion", load("res://audio/explosion.ogg"), AudioService.BUS_SFX, "SFX")
#    AudioService.register_sound("theme", load("res://audio/theme.ogg"), AudioService.BUS_MUSIC, "MUSIC")
# 3) Play sounds:
#    AudioService.play_ui("click")
#    AudioService.play_sfx("explosion", {"pos": Vector2(100, 100), "vol_db": -3})
#    AudioService.play_music_by_id("theme", 1.5, true)
# 4) Save/Load volumes/mutes is automatic if `SaveService` autoload is present.
#
# Public API Highlights
# - Mixer: set_bus_volume_db(bus, db), get_bus_volume_db(bus), set_bus_mute(bus, on), is_bus_mute(bus)
# - Library: register_sound(id, stream_or_def, bus?, kind?, meta?), register_sounds(dict), has_sound(id), get_sound(id)
# - SFX/UI: play_sfx(id, opts), play_sfx_3d(id, opts), play_ui(id, opts), spatial helpers: play_at_node2d/3d, play_at_position2d/3d
# - Music: play_music_by_id(id, fade?, loop?), play_music_stream(stream, fade?, loop?), stop_music(fade?)
# - Pause/Focus: on_scene_paused(), on_scene_resumed() (optional hooks you can call from your game state)
# - Ducking: enabled by default; SFX/UI triggers temporary music duck

# Signals
# Emitted when music starts with a given track id from the sound library
signal music_started(id: StringName)
# Emitted after music has fully stopped (after any fade)
signal music_stopped()
# Emitted when SFX/UI plays; kind is "2D" | "3D" | "UI"
signal sfx_played(id: StringName, kind: String)

# SaveService integration
# AudioService saves/restores mixer volumes/mutes via SaveService, if present.
# The prioritization ensures settings load before most gameplay systems.
const SAVE_ID       : String = "audio_settings_v1"
const SAVE_PRIORITY : int = 30

# Default bus names
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC : StringName = &"Music"
const BUS_SFX   : StringName = &"SFX"
const BUS_UI    : StringName = &"UI"

# Configuration
# If true, publishing simple volume/mute events to EventBus (no subscriptions here).
var mirror_to_eventbus: bool = true
# If true, creates missing buses named in BUS_* at startup.
var create_missing_buses: bool = true

# Process policy: set to true to keep processing when paused (ducking updates, etc.)
var process_always: bool = false: set = _set_process_policy

# Internal: bus state (base volumes persist; offsets are temporary for duck/pause/focus)
var _bus_index: Dictionary = {}              # StringName -> int
var _bus_base_volume_db: Dictionary = {}     # StringName -> float
var _bus_mute: Dictionary = {}               # StringName -> bool
var _bus_offset_db: Dictionary = {}          # StringName -> float (duck/focus/pause)

# Sound library (id -> { stream, bus, kind, meta })
# Register once, then reference by id in play functions.
var _library: Dictionary = {}

# Internal: flags
var _pause_active: bool = false
var _focus_active: bool = true
var _suppress_mirror: bool = false

# Ducking configuration
var duck_enabled: bool = true
var duck_amount_db: float = -8.0
var duck_attack_s: float = 0.04
var duck_hold_s: float = 0.20
var duck_release_s: float = 0.35

# Ducking state
var _duck_current_db: float = 0.0
var _duck_hold_until_ms: int = 0

# Pause/Focus configuration
var pause_duck_db: float = -12.0
var mute_on_pause: bool = false
var pause_music_when_paused: bool = false
var focus_out_duck_db: float = -8.0
var mute_on_focus_out: bool = false

func _ready() -> void:
    _setup_buses()
    _init_bus_state_defaults()
    _create_pool_roots()
    _populate_pools()
    _create_music_players()
    _apply_all_bus_volumes()
    _apply_all_bus_mutes()
    _update_process_policy()
    if not Engine.is_editor_hint():
        SaveService.register_saveable(self)
    # Ensure we start processing for ducking/mix updates
    set_process(true)

# ───────────────────────────────────────────────────────────────────────────────
# Bus Layout & Mixer
# ───────────────────────────────────────────────────────────────────────────────

func _setup_buses() -> void:
    _ensure_bus(BUS_MASTER)
    _ensure_bus(BUS_MUSIC)
    _ensure_bus(BUS_SFX)
    _ensure_bus(BUS_UI)

## Ensure a bus exists and cache its index
func _ensure_bus(bus_name: StringName) -> void:
    var idx := AudioServer.get_bus_index(bus_name)
    if idx == -1 and create_missing_buses:
        AudioServer.add_bus()
        idx = AudioServer.get_bus_count() - 1
        AudioServer.set_bus_name(idx, String(bus_name))
    _bus_index[bus_name] = AudioServer.get_bus_index(bus_name)

func _init_bus_state_defaults() -> void:
    const buses := [BUS_MASTER, BUS_MUSIC, BUS_SFX, BUS_UI]
    for b in buses:
        if not _bus_base_volume_db.has(b):
            var i := AudioServer.get_bus_index(b)
            _bus_base_volume_db[b] = AudioServer.get_bus_volume_db(i) if i >= 0 else 0.0
        if not _bus_mute.has(b):
            var im := AudioServer.get_bus_index(b)
            _bus_mute[b] = AudioServer.is_bus_mute(im) if im >= 0 else false
        _bus_offset_db[b] = 0.0

func _valid_bus(bus: StringName) -> bool:
    return _bus_index.has(bus) and _bus_index[bus] >= 0

## Mixer: set a bus volume (dB). Persists via SaveService.
func set_bus_volume_db(bus: StringName, db: float) -> void:
    if not _valid_bus(bus):
        return
    _bus_base_volume_db[bus] = db
    _apply_bus_volume(bus)
    if mirror_to_eventbus and not _suppress_mirror:
        EventBus.pub(EventTopics.AUDIO_VOLUME_SET, {"bus": bus, "db": db})

## Mixer: get the stored (base) volume for a bus (dB)
func get_bus_volume_db(bus: StringName) -> float:
    return _bus_base_volume_db.get(bus, 0.0)

## Mixer: set mute for a bus. Persists via SaveService.
func set_bus_mute(bus: StringName, mute: bool) -> void:
    if not _valid_bus(bus):
        return
    _bus_mute[bus] = mute
    AudioServer.set_bus_mute(_bus_index[bus], mute)
    if mirror_to_eventbus and not _suppress_mirror:
        EventBus.pub(EventTopics.AUDIO_MUTE_SET, {"bus": bus, "mute": mute})

## Mixer: get mute state for a bus
func is_bus_mute(bus: StringName) -> bool:
    return _bus_mute.get(bus, false)

func _apply_bus_volume(bus: StringName) -> void:
    if not _valid_bus(bus):
        return
    var base_db: float = _bus_base_volume_db.get(bus, 0.0)
    var offset_db: float = _bus_offset_db.get(bus, 0.0)
    AudioServer.set_bus_volume_db(_bus_index[bus], base_db + offset_db)

func _apply_all_bus_volumes() -> void:
    for bus in _bus_index.keys():
        _apply_bus_volume(bus)

func _apply_all_bus_mutes() -> void:
    for bus in _bus_index.keys():
        AudioServer.set_bus_mute(_bus_index[bus], _bus_mute.get(bus, false))

# ───────────────────────────────────────────────────────────────────────────────
# Sound Library
# ───────────────────────────────────────────────────────────────────────────────

## Register a single sound definition.
## stream_or_def can be an AudioStream or Dictionary {stream, bus?, kind?, meta?}
## Args:
##   id: unique identifier
##   stream_or_def: AudioStream or Dictionary as above
##   bus: default bus to route this sound to (e.g., BUS_SFX)
##   kind: optional tag (e.g., "SFX" | "UI" | "MUSIC")
##   meta: arbitrary developer metadata stored with the entry
func register_sound(id: StringName, stream_or_def, bus: StringName = BUS_SFX, kind: String = "SFX", meta: Dictionary = {}) -> void:
    var entry: Dictionary
    if typeof(stream_or_def) == TYPE_DICTIONARY:
        entry = stream_or_def.duplicate(true)
        if not entry.has("stream"):
            push_warning("AudioService.register_sound: missing 'stream' for id %s" % [id])
            return
        entry["bus"] = StringName(entry.get("bus", bus))
        entry["kind"] = String(entry.get("kind", kind))
        entry["meta"] = entry.get("meta", meta)
    else:
        entry = {"stream": stream_or_def, "bus": bus, "kind": kind, "meta": meta}
    _library[String(id)] = entry

## Bulk register sounds: defs is Dictionary[id] = stream or def-dict
func register_sounds(defs: Dictionary) -> void:
    for key in defs.keys():
        register_sound(StringName(key), defs[key])

## Check if a sound id is registered
func has_sound(id: StringName) -> bool:
    return _library.has(String(id))

## Return the raw registered entry for a sound id (or empty Dictionary)
func get_sound(id: StringName) -> Dictionary:
    return _library.get(String(id), {})

# ───────────────────────────────────────────────────────────────────────────────
# SFX Player Pools (2D / 3D / UI) – scaffolding
# ───────────────────────────────────────────────────────────────────────────────

var _pool_root_2d: Node2D
var _pool_root_3d: Node3D
var _pool_root_ui: Node
var _pool_2d_free: Array = []
var _pool_3d_free: Array = []
var _pool_ui_free: Array = []

var sfx2d_initial_size: int = 12
var sfx3d_initial_size: int = 12
var ui_initial_size: int = 6
var sfx2d_max_size: int = 48
var sfx3d_max_size: int = 48
var ui_max_size: int = 24

func _create_pool_roots() -> void:
    _pool_root_2d = Node2D.new()
    _pool_root_2d.name = "Audio2DPool"
    add_child(_pool_root_2d)
    _pool_root_3d = Node3D.new()
    _pool_root_3d.name = "Audio3DPool"
    add_child(_pool_root_3d)
    _pool_root_ui = Node.new()
    _pool_root_ui.name = "AudioUIPool"
    add_child(_pool_root_ui)

func _populate_pools() -> void:
    for i in range(max(0, sfx2d_initial_size)):
        _pool_2d_free.append(_make_2d_player())
    for i in range(max(0, sfx3d_initial_size)):
        _pool_3d_free.append(_make_3d_player())
    for i in range(max(0, ui_initial_size)):
        _pool_ui_free.append(_make_ui_player())

func _make_2d_player() -> AudioStreamPlayer2D:
    var p := AudioStreamPlayer2D.new()
    p.bus = String(BUS_SFX)
    p.finished.connect(_on_player_2d_finished.bind(p))
    _pool_root_2d.add_child(p)
    return p

func _make_3d_player() -> AudioStreamPlayer3D:
    var p := AudioStreamPlayer3D.new()
    p.bus = String(BUS_SFX)
    p.finished.connect(_on_player_3d_finished.bind(p))
    _pool_root_3d.add_child(p)
    return p

func _make_ui_player() -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.bus = String(BUS_UI)
    p.finished.connect(_on_player_ui_finished.bind(p))
    _pool_root_ui.add_child(p)
    return p

func _get_free_2d() -> AudioStreamPlayer2D:
    if _pool_2d_free.is_empty():
        if _pool_root_2d.get_child_count() < sfx2d_max_size:
            return _make_2d_player()
        return _pool_root_2d.get_child(0) as AudioStreamPlayer2D
    return _pool_2d_free.pop_back()

func _get_free_3d() -> AudioStreamPlayer3D:
    if _pool_3d_free.is_empty():
        if _pool_root_3d.get_child_count() < sfx3d_max_size:
            return _make_3d_player()
        return _pool_root_3d.get_child(0) as AudioStreamPlayer3D
    return _pool_3d_free.pop_back()

func _get_free_ui() -> AudioStreamPlayer:
    if _pool_ui_free.is_empty():
        if _pool_root_ui.get_child_count() < ui_max_size:
            return _make_ui_player()
        return _pool_root_ui.get_child(0) as AudioStreamPlayer
    return _pool_ui_free.pop_back()

func _on_player_2d_finished(p: AudioStreamPlayer2D) -> void:
    p.stream = null
    p.pitch_scale = 1.0
    p.volume_db = 0.0
    p.position = Vector2.ZERO
    var parent := p.get_parent()
    if parent != _pool_root_2d:
        parent.remove_child(p)
        _pool_root_2d.add_child(p)
    _pool_2d_free.append(p)

func _on_player_3d_finished(p: AudioStreamPlayer3D) -> void:
    p.stream = null
    p.pitch_scale = 1.0
    p.volume_db = 0.0
    p.transform.origin = Vector3.ZERO
    var parent := p.get_parent()
    if parent != _pool_root_3d:
        parent.remove_child(p)
        _pool_root_3d.add_child(p)
    _pool_3d_free.append(p)

func _on_player_ui_finished(p: AudioStreamPlayer) -> void:
    p.stream = null
    p.pitch_scale = 1.0
    p.volume_db = 0.0
    var parent := p.get_parent()
    if parent != _pool_root_ui:
        parent.remove_child(p)
        _pool_root_ui.add_child(p)
    _pool_ui_free.append(p)

# ───────────────────────────────────────────────────────────────────────────────
# SFX play helpers
# ───────────────────────────────────────────────────────────────────────────────

## Play a 2D sound by id.
## Options:
##   vol_db?: float (default 0.0)
##   pitch?: float (default 1.0)
##   pos?: Vector2
##   parent?: Node (attach the player under this node; defaults to pool root)
func play_sfx(id: StringName, options: Dictionary = {}) -> AudioStreamPlayer2D:
    var def := get_sound(id)
    if def.is_empty():
        push_warning("AudioService.play_sfx: unknown id '%s'" % [id])
        return null
    var stream: AudioStream = def.get("stream")
    if stream == null:
        return null
    var p := _get_free_2d()
    p.bus = String(def.get("bus", BUS_SFX))
    p.stream = stream
    p.volume_db = options.get("vol_db", 0.0)
    p.pitch_scale = options.get("pitch", 1.0)
    if options.has("pos"):
        p.position = options["pos"]
    var parent: Node = options.get("parent", _pool_root_2d)
    var current_parent := p.get_parent()
    if current_parent != parent:
        if current_parent != null:
            current_parent.remove_child(p)
        parent.add_child(p)
    p.play()
    if duck_enabled:
        _request_duck()
    sfx_played.emit(id, "2D")
    return p

## Play a 3D sound by id.
## Options:
##   vol_db?: float (default 0.0)
##   pitch?: float (default 1.0)
##   pos?: Vector3
##   parent?: Node (attach the player under this node; defaults to pool root)
func play_sfx_3d(id: StringName, options: Dictionary = {}) -> AudioStreamPlayer3D:
    var def := get_sound(id)
    if def.is_empty():
        push_warning("AudioService.play_sfx_3d: unknown id '%s'" % [id])
        return null
    var stream: AudioStream = def.get("stream")
    if stream == null:
        return null
    var p := _get_free_3d()
    p.bus = String(def.get("bus", BUS_SFX))
    p.stream = stream
    p.volume_db = options.get("vol_db", 0.0)
    p.pitch_scale = options.get("pitch", 1.0)
    if options.has("pos"):
        var xform := p.transform
        xform.origin = options["pos"]
        p.transform = xform
    var parent: Node = options.get("parent", _pool_root_3d)
    var current_parent := p.get_parent()
    if current_parent != parent:
        if current_parent != null:
            current_parent.remove_child(p)
        parent.add_child(p)
    p.play()
    if duck_enabled:
        _request_duck()
    sfx_played.emit(id, "3D")
    return p

## Play a UI sound by id.
## Options:
##   vol_db?: float (default 0.0)
##   pitch?: float (default 1.0)
func play_ui(id: StringName, options: Dictionary = {}) -> AudioStreamPlayer:
    var def := get_sound(id)
    if def.is_empty():
        push_warning("AudioService.play_ui: unknown id '%s'" % [id])
        return null
    var stream: AudioStream = def.get("stream")
    if stream == null:
        return null
    var p := _get_free_ui()
    p.bus = String(def.get("bus", BUS_UI))
    p.stream = stream
    p.volume_db = options.get("vol_db", 0.0)
    p.pitch_scale = options.get("pitch", 1.0)
    p.play()
    if duck_enabled:
        _request_duck()
    sfx_played.emit(id, "UI")
    return p

func play_at_node2d(id: StringName, node: Node2D, options: Dictionary = {}) -> AudioStreamPlayer2D:
    var new_options := options.duplicate()
    # Shortcut: plays attached to a Node2D at its global position
    new_options["parent"] = node
    new_options["pos"] = node.global_position
    return play_sfx(id, new_options)

func play_at_node3d(id: StringName, node: Node3D, options: Dictionary = {}) -> AudioStreamPlayer3D:
    var new_options := options.duplicate()
    # Shortcut: plays attached to a Node3D at its global origin
    new_options["parent"] = node
    new_options["pos"] = node.global_transform.origin
    return play_sfx_3d(id, new_options)

# ───────────────────────────────────────────────────────────────────────────────
# Music Player & Crossfade
# ───────────────────────────────────────────────────────────────────────────────

var music_crossfade_seconds: float = 1.25  # default crossfade duration when swapping tracks
var music_loop_default: bool = true        # default looping behavior if not specified

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _music_inactive: AudioStreamPlayer
var _music_tween: Tween
var _current_music_id: StringName = StringName("")

## Internal: create two music players for crossfading
func _create_music_players() -> void:
    _music_a = AudioStreamPlayer.new()
    _music_b = AudioStreamPlayer.new()
    _music_a.bus = String(BUS_MUSIC)
    _music_b.bus = String(BUS_MUSIC)
    _music_a.name = "MusicA"
    _music_b.name = "MusicB"
    add_child(_music_a)
    add_child(_music_b)
    _music_active = _music_a
    _music_inactive = _music_b

## Internal: set loop on known AudioStream types
func _set_stream_loop(stream: AudioStream, loop: bool) -> void:
    if stream is AudioStreamOggVorbis:
        (stream as AudioStreamOggVorbis).loop = loop
    elif stream is AudioStreamMP3:
        (stream as AudioStreamMP3).loop = loop
    elif stream is AudioStreamWAV:
        (stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED

## Play music by id, crossfading from current track
## Args:
##   id: sound id registered with kind "MUSIC" (convention only)
##   fade_seconds: duration; if < 0, uses music_crossfade_seconds
##   loop: whether the stream should loop
func play_music_by_id(id: StringName, fade_seconds: float = -1.0, loop: bool = true) -> void:
    var def := get_sound(id)
    if def.is_empty():
        push_warning("AudioService.play_music_by_id: unknown id '%s'" % [id])
        return
    var stream: AudioStream = def.get("stream")
    if stream == null:
        return
    play_music_stream(stream, fade_seconds, loop)
    _current_music_id = id
    music_started.emit(id)

## Play a raw music stream, crossfading from current track
## Args:
##   stream: AudioStream resource
##   fade_seconds: duration; if < 0, uses music_crossfade_seconds
##   loop: whether the stream should loop
func play_music_stream(stream: AudioStream, fade_seconds: float = -1.0, loop: bool = true) -> void:
    if fade_seconds < 0.0:
        fade_seconds = music_crossfade_seconds
    if _music_tween and _music_tween.is_valid():
        _music_tween.kill()
    _music_inactive.stop()
    _set_stream_loop(stream, loop)
    _music_inactive.stream = stream
    _music_inactive.volume_db = -60.0
    _music_inactive.pitch_scale = 1.0
    _music_inactive.bus = String(BUS_MUSIC)
    _music_inactive.play()
    _music_inactive.stream_paused = false
    _music_active.stream_paused = false
    _music_tween = create_tween()
    _music_tween.tween_property(_music_inactive, "volume_db", 0.0, fade_seconds)
    _music_tween.parallel().tween_property(_music_active, "volume_db", -60.0, fade_seconds)
    _music_tween.finished.connect(_on_music_crossfade_done)

func _on_music_crossfade_done() -> void:
    _music_active.stop()
    var tmp := _music_active
    _music_active = _music_inactive
    _music_inactive = tmp

## Stop music with an optional fade-out
func stop_music(fade_seconds: float = 0.5) -> void:
    if _music_tween and _music_tween.is_valid():
        _music_tween.kill()
    _music_tween = create_tween()
    _music_tween.tween_property(_music_active, "volume_db", -60.0, max(0.0, fade_seconds))
    _music_tween.finished.connect(func():
        _music_active.stop()
        _current_music_id = StringName("")
        music_stopped.emit()
    )

# ───────────────────────────────────────────────────────────────────────────────
# Ducking & Focus/Pause handling
# ───────────────────────────────────────────────────────────────────────────────

## Internal: trigger a duck event (hold timer) for music bus
func _request_duck() -> void:
    var now := Time.get_ticks_msec()
    _duck_hold_until_ms = now + int(duck_hold_s * 1000.0)

## Process: advances ducking envelope and applies effective mix
func _process(delta: float) -> void:
    _update_ducking(delta)
    _apply_effective_mix()

## Internal: update ducking envelope (attack/hold/release)
func _update_ducking(delta: float) -> void:
    if not duck_enabled:
        _duck_current_db = 0.0
        return
    var now := Time.get_ticks_msec()
    var want := duck_amount_db if now <= _duck_hold_until_ms else 0.0
    var rate := duck_attack_s if want < _duck_current_db else duck_release_s
    rate = max(rate, 0.0001)
    var t: float = clampf(delta / rate, 0.0, 1.0)
    _duck_current_db = lerp(_duck_current_db, want, t)

## Internal: compute and apply bus offsets and mutes based on duck/pause/focus
func _apply_effective_mix() -> void:
    # Apply dynamic offsets and mutes derived from ducking/pause/focus
    var music_offset := 0.0
    music_offset += _duck_current_db
    if _pause_active:
        music_offset += pause_duck_db
    if not _focus_active:
        music_offset += focus_out_duck_db
    _bus_offset_db[BUS_MUSIC] = music_offset

    if mute_on_pause:
        AudioServer.set_bus_mute(_bus_index[BUS_SFX], _pause_active)
        AudioServer.set_bus_mute(_bus_index[BUS_UI], _pause_active)
    if mute_on_focus_out:
        AudioServer.set_bus_mute(_bus_index[BUS_SFX], not _focus_active)
        AudioServer.set_bus_mute(_bus_index[BUS_UI], not _focus_active)

    _apply_all_bus_volumes()

## Optional hook: call when your game pauses to apply audio pause policy
func on_scene_paused() -> void:
    _pause_active = true
    if pause_music_when_paused:
        _music_active.stream_paused = true
        _music_inactive.stream_paused = true

## Optional hook: call when your game resumes to revert pause policy
func on_scene_resumed() -> void:
    _pause_active = false
    if pause_music_when_paused:
        _music_active.stream_paused = false
        _music_inactive.stream_paused = false

## Receives focus in/out notifications to adjust audio focus policy
func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_FOCUS_IN:
            _focus_active = true
        NOTIFICATION_APPLICATION_FOCUS_OUT:
            _focus_active = false

func play_at_position2d(id: StringName, pos: Vector2, options: Dictionary = {}) -> AudioStreamPlayer2D:
    var new_options := options.duplicate()
    # Shortcut: plays at a specific 2D position using the pool root as parent
    new_options["pos"] = pos
    return play_sfx(id, new_options)

func play_at_position3d(id: StringName, pos: Vector3, options: Dictionary = {}) -> AudioStreamPlayer3D:
    var new_options := options.duplicate()
    # Shortcut: plays at a specific 3D position using the pool root as parent
    new_options["pos"] = pos
    return play_sfx_3d(id, new_options)

# ───────────────────────────────────────────────────────────────────────────────
# SaveService interface
# ───────────────────────────────────────────────────────────────────────────────

func save_data() -> Dictionary:
    var vols := {}
    var mutes := {}
    const buses := [BUS_MASTER, BUS_MUSIC, BUS_SFX, BUS_UI]
    for b in buses:
        vols[b] = _bus_base_volume_db.get(b, 0.0)
        mutes[b] = _bus_mute.get(b, false)
    return {
        "volumes": vols,
        "mutes": mutes
    }

func load_data(data: Dictionary) -> bool:
    if data.has("volumes"):
        var vols: Dictionary = data.volumes
        for b in vols.keys():
            set_bus_volume_db(StringName(b), vols[b])
    if data.has("mutes"):
        var mutes: Dictionary = data.mutes
        for b in mutes.keys():
            set_bus_mute(StringName(b), mutes[b])
    return true

func get_save_id() -> String:
    return SAVE_ID

func get_save_priority() -> int:
    return SAVE_PRIORITY

# ───────────────────────────────────────────────────────────────────────────────
# Misc helpers
# ───────────────────────────────────────────────────────────────────────────────

func _set_process_policy(always: bool) -> void:
    process_always = always
    _update_process_policy()

func _update_process_policy() -> void:
    process_mode = Node.PROCESS_MODE_WHEN_PAUSED if process_always else Node.PROCESS_MODE_PAUSABLE