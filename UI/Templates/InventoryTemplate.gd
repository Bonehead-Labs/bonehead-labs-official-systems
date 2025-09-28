class_name _InventoryTemplate
extends _UITemplate

const KEY_TITLE: StringName = StringName("title")
const KEY_SLOTS: StringName = StringName("slots")
const KEY_COLUMNS: StringName = StringName("columns")

@export var title_label_path: NodePath = NodePath("Layout/Header")
@export var grid_container_path: NodePath = NodePath("Layout/Grid/Slots")

var _title_label: Label
var _grid: GridContainer

func _on_template_ready() -> void:
    _title_label = get_node_or_null(title_label_path) as Label
    _grid = get_node_or_null(grid_container_path) as GridContainer

func _apply_content(content: Dictionary) -> void:
    if _title_label != null and content.has(KEY_TITLE):
        _UITemplateDataBinder.apply_text(_title_label, content[KEY_TITLE], Callable(self, "resolve_text"))
    if _grid == null:
        return
    
    # Calculate optimal column count based on available width
    var column_count: int = int(content.get(KEY_COLUMNS, 4))
    if column_count > 0:
        _grid.columns = column_count
        print("InventoryTemplate: Using fixed column count: ", column_count)
    else:
        # Auto-calculate columns based on available width
        var scroll_container = _grid.get_parent() as ScrollContainer
        var available_width = scroll_container.size.x if scroll_container else 500
        var slot_width = 120 + 8  # button width + separation
        var calculated_columns = max(1, int(available_width / slot_width))
        _grid.columns = calculated_columns
        print("InventoryTemplate: Auto-calculated columns: ", calculated_columns, " (available width: ", available_width, ")")
    
    var slots: Array = []
    if content.get(KEY_SLOTS) is Array:
        slots = content[KEY_SLOTS]
    _UITemplateDataBinder.populate_container(_grid, slots, Callable(self, "_create_slot"))

func _create_slot(descriptor: Variant) -> Node:
    if descriptor is Dictionary:
        return _build_slot(descriptor)
    return _build_slot({StringName("label"): descriptor})

func _build_slot(data: Dictionary) -> Node:
    var slot = InventorySlot.new()
    slot.set_slot_data(data)
    
    # Connect the slot's signal to our template event system
    slot.slot_clicked.connect(_on_slot_clicked)
    
    return slot

func _on_slot_clicked(slot_data: Dictionary) -> void:
    var slot_id: StringName = slot_data.get(StringName("id"), StringName()) as StringName
    var event_id: StringName = slot_data.get(StringName("event"), slot_id) as StringName
    var payload: Dictionary = slot_data.get(StringName("payload"), {}) as Dictionary
    
    var enriched: Dictionary = payload.duplicate(true)
    if slot_id != StringName():
        enriched[StringName("slot_id")] = slot_id
    
    emit_template_event(event_id, enriched)
