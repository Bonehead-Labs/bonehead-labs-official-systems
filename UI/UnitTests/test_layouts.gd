extends "res://addons/gut/test.gd"

const ThemeServicePath: String = "res://UI/Theme/ThemeService.gd"
const PanelShellScene: String = "res://UI/Layouts/PanelShell.tscn"
const DialogShellScene: String = "res://UI/Layouts/DialogShell.tscn"
const LogShellScene: String = "res://UI/Layouts/ScrollableLogShell.tscn"

var theme_service: _ThemeService

func before_each() -> void:
    theme_service = load(ThemeServicePath).new()
    theme_service.name = "ThemeService"
    get_tree().root.add_child(theme_service)
    await theme_service.ready

func after_each() -> void:
    if is_instance_valid(theme_service):
        theme_service.queue_free()
        await get_tree().process_frame

func test_panel_shell_reacts_to_theme_change() -> void:
    var panel_shell := load(PanelShellScene).instantiate() as PanelContainer
    get_tree().root.add_child(panel_shell)
    await get_tree().process_frame
    var initial_style := panel_shell.get_theme_stylebox("panel") as StyleBoxFlat
    assert_true(initial_style is StyleBoxFlat)
    var initial_color := initial_style.bg_color
    theme_service.enable_high_contrast(true)
    await get_tree().process_frame
    var updated_style := panel_shell.get_theme_stylebox("panel") as StyleBoxFlat
    assert_true(updated_style is StyleBoxFlat)
    assert_neq(initial_color, updated_style.bg_color)
    panel_shell.queue_free()

func test_dialog_shell_configures_title_and_actions() -> void:
    var dialog_shell := load(DialogShellScene).instantiate() as PanelContainer
    get_tree().root.add_child(dialog_shell)
    await get_tree().process_frame
    var dialog_script := dialog_shell as Node
    dialog_script.call("set_title", "Testing")
    dialog_script.call("set_description", "Description text")
    var title_label := dialog_shell.get_node("Layout/HeaderSlot/TitleLabel") as Label
    var description_label := dialog_shell.get_node("Layout/HeaderSlot/DescriptionLabel") as Label
    assert_eq(title_label.text, "Testing")
    assert_true(title_label.visible)
    assert_eq(description_label.text, "Description text")
    assert_true(description_label.visible)
    var action_button := Button.new()
    dialog_script.call("add_action", action_button)
    var action_bar := dialog_shell.get_node("Layout/FooterSlot/ActionBar") as BoxContainer
    assert_eq(action_bar.get_child_count(), 1)
    theme_service.enable_high_contrast(true)
    await get_tree().process_frame
    assert_gt(action_bar.get_theme_constant("separation"), 0)
    dialog_shell.queue_free()

func test_scrollable_log_shell_limits_entries() -> void:
    var log_shell := load(LogShellScene).instantiate() as PanelContainer
    get_tree().root.add_child(log_shell)
    await get_tree().process_frame
    var log_script := log_shell as Node
    for index in range(70):
        log_script.call("append_entry", "Entry %d" % index)
    var log_view := log_shell.get_node("Layout/BodySlot/LogViewContainer/LogView") as RichTextLabel
    assert_true(log_view.text.ends_with("Entry 69"))
    var lines := log_view.text.split("\n")
    var limit := int(log_script.get("max_entries"))
    assert_true(lines.size() <= limit)
    theme_service.enable_high_contrast(true)
    await get_tree().process_frame
    var panel_style := log_shell.get_theme_stylebox("panel")
    assert_true(panel_style is StyleBox)
    log_shell.queue_free()
