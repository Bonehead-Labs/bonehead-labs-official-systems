extends Node
# Per-project list of actions/contexts/axes. Change this per game.
const ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "pause", "interact", "attack", "dash", "fireball", "inventory",
	"debug_toggle_inspector",
	"ui_accept", "ui_cancel", "ui_settings"
]

const CONTEXTS := {                      # action groups you can toggle
	"gameplay": [
		"move_left","move_right","move_up","move_down",
		"jump","pause","interact","attack","dash","fireball","inventory",
		"debug_toggle_inspector"
	],
    "ui":       ["ui_accept","ui_cancel","ui_settings"]
}

const AXES := {                          # simple axis wiring
    "move_x": {"neg": "move_left", "pos": "move_right"},
    "move_y": {"neg": "move_up", "pos": "move_down"}
}
