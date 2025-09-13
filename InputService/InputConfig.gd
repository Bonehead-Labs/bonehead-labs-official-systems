# Per-project list of actions/contexts/axes. Change this per game.
const ACTIONS := [
    "move_left", "move_right",
    "jump", "pause",
    "ui_accept", "ui_cancel"
]

const CONTEXTS := {                      # action groups you can toggle
    "gameplay": ["move_left","move_right","jump","pause"],
    "ui":       ["ui_accept","ui_cancel"]
}

const AXES := {                          # simple axis wiring
    "move_x": {"neg": "move_left", "pos": "move_right"}
}
