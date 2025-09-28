extends Resource

## Example menu schema demonstrating MenuBuilder fields.
##
## [b]Deprecated:[/b] MenuBuilder is superseded by template-driven UI scenes.
## Convert schemas to template data dictionaries (see `UI/Templates/README.md`).
##
## [b]Usage:[/b]
## [codeblock]
## var builder := _MenuBuilder.new()
## builder.action_callbacks = {
##     StringName("apply_changes"): Callable(self, "_on_apply_changes"),
##     StringName("close_menu"): Callable(self, "_on_close_menu"),
##     StringName("toggle_fullscreen"): Callable(self, "_on_toggle_fullscreen"),
##     StringName("show_resolution"): Callable(self, "_on_show_resolution")
## }
## var menu := builder.build_menu(load("res://UI/Layouts/menu_schema.example.gd").MENU_SCHEMA)
## add_child(menu)
## [/codeblock]
##
## [b]Sections:[/b] declare layout (`vbox` or `hbox`), display headers, and
## controls created through WidgetFactory (`button`, `toggle`, `label`, `slider`).
## [b]Actions:[/b] describe signal bindings and callback identifiers. Callbacks
## must be supplied through `action_callbacks` before building.
## [b]Footer:[/b] supports `mode = "actions"` for DialogShells, otherwise a
## container layout is injected into the footer slot.
const MENU_SCHEMA: Dictionary = {
    "menu_id": "settings_menu",
    "shell_scene": "res://UI/Layouts/DialogShell.tscn",
    "shell": {
        "header": {
            "title": {
                "token": StringName("ui/settings/title"),
                "fallback": "Settings"
            },
            "description": {
                "fallback": "Adjust gameplay and audio options."
            }
        },
        "footer": {
            "mode": "actions",
            "controls": [
                {
                    "id": "apply_button",
                    "factory": "button",
                    "config": {
                        "label_token": StringName("ui/common/apply"),
                        "label_fallback": "Apply"
                    },
                    "action": "apply_changes"
                },
                {
                    "id": "close_button",
                    "factory": "button",
                    "config": {
                        "label_token": StringName("ui/common/close"),
                        "label_fallback": "Close"
                    },
                    "action": "close_menu"
                }
            ]
        }
    },
    "sections": [
        {
            "id": "display_section",
            "layout": "vbox",
            "title": {
                "token": StringName("ui/settings/display"),
                "fallback": "Display"
            },
            "controls": [
                {
                    "id": "fullscreen_toggle",
                    "factory": "toggle",
                    "config": {
                        "label_token": StringName("ui/settings/fullscreen"),
                        "label_fallback": "Full Screen"
                    },
                    "action": "toggle_fullscreen"
                },
                {
                    "id": "resolution_button",
                    "factory": "button",
                    "config": {
                        "label_token": StringName("ui/settings/resolution"),
                        "label_fallback": "Change Resolution"
                    },
                    "action": "show_resolution"
                }
            ]
        },
        {
            "id": "audio_section",
            "layout": "vbox",
            "title": {
                "token": StringName("ui/settings/audio"),
                "fallback": "Audio"
            },
            "controls": [
                {
                    "id": "music_volume_slider",
                    "factory": "slider",
                    "config": {
                        "min_value": 0.0,
                        "max_value": 1.0,
                        "step": 0.05,
                        "value": 0.8
                    },
                    "action": "adjust_music_volume"
                }
            ]
        }
    ],
    "actions": {
        "apply_changes": {
            "signal": "pressed",
            "callback": "apply_changes"
        },
        "close_menu": {
            "signal": "pressed",
            "callback": "close_menu"
        },
        "toggle_fullscreen": {
            "signal": "toggled",
            "callback": "toggle_fullscreen"
        },
        "show_resolution": {
            "signal": "pressed",
            "callback": "show_resolution"
        },
        "adjust_music_volume": {
            "signal": "value_changed",
            "callback": "adjust_music_volume",
            "payload": {
                "setting": "music_volume"
            }
        }
    }
}
