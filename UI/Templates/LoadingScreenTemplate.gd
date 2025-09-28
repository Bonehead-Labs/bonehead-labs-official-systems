class_name _LoadingScreenTemplate
extends _UITemplate

const KEY_TITLE: StringName = StringName("title")
const KEY_SUBTITLE: StringName = StringName("subtitle")
const KEY_TIP: StringName = StringName("tip")
const KEY_PROGRESS: StringName = StringName("progress")

@export var title_label_path: NodePath = NodePath("Layout/Title")
@export var subtitle_label_path: NodePath = NodePath("Layout/Subtitle")
@export var tip_label_path: NodePath = NodePath("Layout/Tip")
@export var progress_bar_path: NodePath = NodePath("Layout/Progress")

var _title_label: Label
var _subtitle_label: Label
var _tip_label: RichTextLabel
var _progress_bar: ProgressBar

func _on_template_ready() -> void:
    _title_label = get_node_or_null(title_label_path) as Label
    _subtitle_label = get_node_or_null(subtitle_label_path) as Label
    _tip_label = get_node_or_null(tip_label_path) as RichTextLabel
    _progress_bar = get_node_or_null(progress_bar_path) as ProgressBar

func _apply_content(content: Dictionary) -> void:
    if _title_label != null and content.has(KEY_TITLE):
        _UITemplateDataBinder.apply_text(_title_label, content[KEY_TITLE], Callable(self, "resolve_text"))
    if _subtitle_label != null and content.has(KEY_SUBTITLE):
        _UITemplateDataBinder.apply_text(_subtitle_label, content[KEY_SUBTITLE], Callable(self, "resolve_text"))
    if _tip_label != null and content.has(KEY_TIP):
        _UITemplateDataBinder.apply_rich_text(_tip_label, content[KEY_TIP], Callable(self, "resolve_text"))
    if _progress_bar != null and content.has(KEY_PROGRESS):
        var progress_data: Dictionary = content[KEY_PROGRESS] as Dictionary
        _UITemplateDataBinder.apply_progress(_progress_bar, progress_data)

func set_progress(value: float, max_value: float = 1.0) -> void:
    if _progress_bar == null:
        return
    _progress_bar.max_value = max_value
    _progress_bar.value = value

func update_tip(tip: Variant) -> void:
    if _tip_label == null:
        return
    _UITemplateDataBinder.apply_rich_text(_tip_label, tip, Callable(self, "resolve_text"))
