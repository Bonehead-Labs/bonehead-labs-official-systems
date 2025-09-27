class_name _ScrollableLogShell
extends _PanelShell

@export var log_label_path: NodePath = NodePath("Layout/BodySlot/LogViewContainer/LogView")
@export var max_entries: int = 64

var _log_label: RichTextLabel
var _entries: Array[String] = []

func _ready() -> void:
    super()
    _log_label = get_node_or_null(log_label_path) as RichTextLabel
    if _log_label:
        _log_label.scroll_active = true
        _log_label.fit_content = false
        _log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

## Replace the scrollback contents with the provided lines.
##
## [param entries] Array of lines that should populate the log view.
func set_entries(entries: Array[String]) -> void:
    _entries = entries.duplicate()
    _truncate_entries()
    _refresh_text()

## Append a new line to the scrollback.
##
## [param entry] Line added to the end of the log view.
func append_entry(entry: String) -> void:
    _entries.append(entry)
    _truncate_entries()
    _refresh_text()

## Clear all log entries.
func clear_entries() -> void:
    _entries.clear()
    _refresh_text()

func _truncate_entries() -> void:
    if max_entries <= 0:
        return
    while _entries.size() > max_entries:
        _entries.pop_front()

func _refresh_text() -> void:
    if _log_label == null:
        return
    _log_label.text = "\n".join(_entries)
