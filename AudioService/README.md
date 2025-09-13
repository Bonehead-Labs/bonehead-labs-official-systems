## AudioService (Godot 4) – High‑Level Usage

Simple, reusable audio manager for games. It provides:
- Buses and mixer helpers (Master, Music, SFX, UI)
- Sound library (register sounds by id, play by id)
- Pooled SFX players (2D/3D) + spatial helpers
- Music player with crossfade
- Automatic ducking when SFX/UI play
- Pause/focus handling (optional)
- Settings persistence via SaveService

### Install (1 minute)
1) Add `AudioService/AudioService.gd` as an autoload singleton named `AudioService`.
2) Ensure the default buses exist (created automatically if missing): `Master`, `Music`, `SFX`, `UI`.

### One‑time setup: register your sounds
Register sounds once (e.g., in a bootstrap scene or main menu).

```gdscript
# UI
AudioService.register_sound(&"ui_click", load("res://audio/ui_click.ogg"), AudioService.BUS_UI, "UI")

# SFX
AudioService.register_sound(&"explosion", load("res://audio/explosion.ogg"), AudioService.BUS_SFX, "SFX")

# Music
AudioService.register_sound(&"theme", load("res://audio/theme.ogg"), AudioService.BUS_MUSIC, "MUSIC")
```

### Play sounds (the basics)
UI:
```gdscript
AudioService.play_ui(&"ui_click")
```

2D SFX at a position:
```gdscript
AudioService.play_sfx(&"explosion", {"pos": Vector2(320, 180), "vol_db": -3.0})
```

2D SFX attached to a Node2D:
```gdscript
AudioService.play_at_node2d(&"explosion", $Enemy)
```

3D SFX at a position:
```gdscript
AudioService.play_sfx_3d(&"explosion", {"pos": Vector3(0, 1, 0)})
```

3D SFX attached to a Node3D:
```gdscript
AudioService.play_at_node3d(&"explosion", $Crate3D)
```

### Music with crossfade
Play by id (auto‑crossfades from the current track):
```gdscript
AudioService.play_music_by_id(&"theme", 1.5, true)  # fade 1.5s, loop true
```

Stop with a short fade:
```gdscript
AudioService.stop_music(0.5)
```

### Mixer: volumes and mute
Set volumes in decibels (persisted via SaveService):
```gdscript
AudioService.set_bus_volume_db(AudioService.BUS_MUSIC, -6.0)
AudioService.set_bus_volume_db(AudioService.BUS_SFX, -3.0)
```

Mute/unmute buses:
```gdscript
AudioService.set_bus_mute(AudioService.BUS_UI, true)
AudioService.set_bus_mute(AudioService.BUS_UI, false)
```

### Ducking (automatic)
When SFX/UI play, the Music bus is briefly ducked so effects stand out.

Tweak or disable:
```gdscript
AudioService.duck_enabled = true
AudioService.duck_amount_db = -8.0   # how much to dip the music
AudioService.duck_hold_s = 0.20      # how long to hold before releasing
```

### Pause & focus (optional)
Call these from your game state when pausing/resuming:
```gdscript
AudioService.pause_music_when_paused = true
AudioService.mute_on_pause = false

AudioService.on_scene_paused()   # when your game pauses
AudioService.on_scene_resumed()  # when your game resumes
```

Window focus is handled automatically: losing focus can optionally reduce or mute.
```gdscript
AudioService.focus_out_duck_db = -8.0
AudioService.mute_on_focus_out = false
```

### Save/Load settings (via SaveService)
Bus volumes and mute states persist automatically if `SaveService` is set up.

```gdscript
# typical pattern
SaveService.set_current_profile("player1")
SaveService.save_game("main")
SaveService.load_game("main")
```

### API cheat sheet
- Register: `register_sound(id, stream_or_def, bus?, kind?, meta?)`
- Library: `has_sound(id)`, `get_sound(id)`
- SFX/UI: `play_sfx(id, opts)`, `play_sfx_3d(id, opts)`, `play_ui(id, opts)`
- Spatial helpers: `play_at_node2d/3d(id, node)`, `play_at_position2d/3d(id, pos)`
- Music: `play_music_by_id(id, fade?, loop?)`, `play_music_stream(stream, fade?, loop?)`, `stop_music(fade?)`
- Mixer: `set_bus_volume_db(bus, db)`, `get_bus_volume_db(bus)`, `set_bus_mute(bus, on)`, `is_bus_mute(bus)`

### Tips
- Keep ids short and consistent (e.g., `ui_click`, `explosion_big`, `theme_day`).
- Use `vol_db` for small per‑play adjustments (e.g., `-3.0` for slightly quieter).
- Register all sounds in one place (bootstrap) to keep your project organized.


