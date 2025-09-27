
# Per-project list of actions/contexts/axes. Change this per game.
const ACTIONS := [
    "move_left", "move_right", "move_up", "move_down",
    "jump", "pause", "interact", "attack",
    "debug_toggle_inspector",
    "ui_accept", "ui_cancel"
]

const CONTEXTS := {                      # action groups you can toggle
    "gameplay": [
        "move_left","move_right","move_up","move_down",
        "jump","pause","interact","attack",
        "debug_toggle_inspector"
    ],
    "ui":       ["ui_accept","ui_cancel"]
}

const AXES := {                          # simple axis wiring
    "move_x": {"neg": "move_left", "pos": "move_right"},
    "move_y": {"neg": "move_up", "pos": "move_down"}
}
