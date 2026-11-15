class_name EscapeMenu
extends CanvasLayer
## A small menu that Escape opens and closes over a match or the random battle: Resume, or
## go back to the main menu. It doesn't pause anything (an online match can't be paused).
## The scene that adds it decides what leaving does, through `on_main_menu`.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

## Called by the Main menu button. Defaults to just switching to the main menu.
var on_main_menu: Callable

var _shade: ColorRect


func _init(leave: Callable = Callable()) -> void:
	on_main_menu = leave
	layer = 100


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.45)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.11, 0.96)
	style.border_color = Color(0.38, 0.38, 0.44)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(220, 0)
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	column.add_child(_button("Resume", close))
	column.add_child(_button("Main menu", _leave))
	close()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(action)
	return button


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _shade.visible


func open() -> void:
	_shade.visible = true


func close() -> void:
	_shade.visible = false


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func _leave() -> void:
	close()
	if on_main_menu.is_valid():
		on_main_menu.call()
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
