extends RefCounted

const AUTOLOAD_NAME: StringName = &"ThemeService"
const SCRIPT_PATH: String = "res://UI/Theme/ThemeService.gd"
const AUTOLOAD_SETTING: String = "autoload/%s" % AUTOLOAD_NAME

## Register the ThemeService autoload in an idempotent fashion
## 
## Ensures the ThemeService is registered as an autoload singleton.
## Only works in the editor and skips if already registered.
## 
## [b]save_settings:[/b] Whether to save project settings immediately (default: true)
## 
## [b]Usage:[/b]
## [codeblock]
## # Register ThemeService autoload
## ThemeServiceAutoloadSetup.ensure_registered()
## [/codeblock]
static func ensure_registered(save_settings: bool = true) -> void:
    if not Engine.is_editor_hint():
        return
        
    var existing: Dictionary = _get_current_entry()
    if existing.size() > 0 and existing.get("path", "") == SCRIPT_PATH:
        return
        
    ProjectSettings.set_setting(AUTOLOAD_SETTING, {"path": SCRIPT_PATH, "singleton": true})
    if save_settings:
        ProjectSettings.save()

## Remove the ThemeService autoload if it matches this module's script path
## 
## Removes the ThemeService autoload registration from project settings.
## Only works in the editor and only removes if it matches our script path.
## 
## [b]save_settings:[/b] Whether to save project settings immediately (default: true)
## 
## [b]Usage:[/b]
## [codeblock]
## # Remove ThemeService autoload
## ThemeServiceAutoloadSetup.ensure_removed()
## [/codeblock]
static func ensure_removed(save_settings: bool = true) -> void:
    if not Engine.is_editor_hint():
        return
        
    var existing: Dictionary = _get_current_entry()
    if existing.size() > 0 and existing.get("path", "") != SCRIPT_PATH:
        return
        
    if ProjectSettings.has_setting(AUTOLOAD_SETTING):
        ProjectSettings.clear(AUTOLOAD_SETTING)
    if save_settings:
        ProjectSettings.save()

## Get the current autoload entry from project settings
## 
## Retrieves the current autoload configuration for ThemeService
## from project settings.
## 
## [b]Returns:[/b] Dictionary containing autoload configuration or empty dict if not found
static func _get_current_entry() -> Dictionary:
    if not ProjectSettings.has_setting(AUTOLOAD_SETTING):
        return {}
        
    var value: Variant = ProjectSettings.get_setting(AUTOLOAD_SETTING)
    if typeof(value) == TYPE_DICTIONARY:
        return value as Dictionary
    return {}
