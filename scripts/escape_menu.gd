class_name EscapeMenu
extends CanvasLayer
## A small menu that Escape opens and closes over a match or the random battle: Resume,
## Settings, or go back to the main menu. It doesn't pause anything (an online match can't
## be paused). The scene that adds it decides what leaving does, through `on_main_menu`.
## Settings (GameSettings, saved between sessions): the sound effects and music volumes.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

## Called by the Main menu button. Defaults to just switching to the main menu.
var on_main_menu: Callable

var _shade: ColorRect
var _main_page: VBoxContainer
var _settings_page: VBoxContainer
## The volume rows on the Settings page: [slider, percent label, getter, setter].
var _volume_rows: Array = []


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
	var pages := VBoxContainer.new()
	panel.add_child(pages)
	_main_page = _page("Menu")
	pages.add_child(_main_page)
	_main_page.add_child(_button("Resume", close))
	_main_page.add_child(_button("Settings", _show_settings))
	_main_page.add_child(_button("Main menu", _leave))
	_settings_page = _page("Settings")
	_settings_page.visible = false
	pages.add_child(_settings_page)
	_build_settings(_settings_page)
	close()


## A page of the menu: a column with its title on top.
func _page(heading: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(260, 0)
	column.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	return column


func _build_settings(page: VBoxContainer) -> void:
	var section := Label.new()
	section.text = "Sound"
	section.add_theme_font_size_override("font_size", 15)
	section.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	page.add_child(section)
	var grid := GridContainer.new()   # names, sliders and percentages each line up
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	page.add_child(grid)
	_volume_row(grid, "Effects", GameSettings.effects_volume, GameSettings.set_effects_volume)
	_volume_row(grid, "Music", GameSettings.music_volume, GameSettings.set_music_volume)
	page.add_child(_button("Back", _show_main))


## One volume setting: its name, a 0-100% slider and the percentage. `getter` returns the
## saved volume (0 to 1); `setter(volume, save_now)` applies it.
func _volume_row(grid: GridContainer, title: String, getter: Callable, setter: Callable) -> void:
	var name_label := Label.new()
	name_label.text = title
	grid.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(140, 0)
	# A visible track the whole way across (the default one is nearly black on this panel).
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.28, 0.28, 0.33)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = Color(0.62, 0.62, 0.7)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	grid.add_child(slider)
	var percent := Label.new()
	percent.custom_minimum_size = Vector2(44, 0)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(percent)
	slider.value_changed.connect(func(value: float):
		percent.text = "%d%%" % int(value)
		# Saved when the drag ends; a click or key press (no drag) saves at once.
		setter.call(value / 100.0, not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)))
	slider.drag_ended.connect(func(_changed: bool): GameSettings.save())
	_volume_rows.append([slider, percent, getter])


## Shows the saved volumes on the sliders (without saving them again).
func _sync_volume() -> void:
	for row in _volume_rows:
		var slider: HSlider = row[0]
		slider.set_value_no_signal(roundf(row[2].call() * 100.0))
		row[1].text = "%d%%" % int(slider.value)


func _show_settings() -> void:
	_sync_volume()
	_main_page.visible = false
	_settings_page.visible = true


func _show_main() -> void:
	_settings_page.visible = false
	_main_page.visible = true


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
	if _settings_page.visible:
		GameSettings.save()   # in case a drag never reported its end
	_show_main()   # it always opens on the main page


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
