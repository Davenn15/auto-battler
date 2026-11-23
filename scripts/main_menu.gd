extends Control
## The start screen: a Setup panel (factions, the host's address) and, apart from it, the
## buttons that start a game: play the computer, watch computers, host or join an online
## match, or open the random battle sandbox.

const MATCH_SCENE := "res://scenes/match.tscn"
const RANDOM_BATTLE_SCENE := "res://scenes/random_battle.tscn"
const SETTINGS_PATH := "user://menu.cfg"   # remembers the last address you joined
## The computer opponent's background battle tester (see AiPlanner).
const AI_EVAL_SCENE := "res://scenes/ai_eval.tscn"

var _buttons: VBoxContainer
var _address: LineEdit
var _status: Label
var _cancel: Button
var _your_faction: OptionButton
var _computer_faction: OptionButton
var _blue_faction: OptionButton
var _red_faction: OptionButton


func _ready() -> void:
	# A background copy started by the computer opponent to test its plans: hand straight
	# over to the tester.
	if OS.get_cmdline_user_args().has("--ai-eval"):
		get_tree().change_scene_to_file.call_deferred(AI_EVAL_SCENE)
		return
	# Testing an exported build: "<game>.exe --headless -- --net-test --offline" plays
	# a match by itself (see tools/net_test.gd).
	if OS.get_cmdline_user_args().has("--net-test"):
		get_tree().change_scene_to_file.call_deferred("res://tools/net_test.tscn")
		return
	# Back to plain offline play, whatever state the last match left things in.
	AiPool.stop()   # no background copies outlive a match
	Net.leave()
	BattleUnit.view_rotation = 0.0
	BattleUnit.swap_team_colors = false
	MatchGame.spectating = false
	Engine.time_scale = 1.0
	_carry_over_settings()
	Net.hosted.connect(_on_hosted)
	Net.match_ready.connect(_on_match_ready)
	Net.connection_failed.connect(_on_connection_failed)
	_build()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.07, 0.07, 0.09)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(560, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var title := Label.new()
	title.text = "GAMBIT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 14)
	column.add_child(_buttons)

	# Setup: choices that don't start anything (factions, the host's address), in a quiet
	# panel above the buttons that do.
	var setup := _section("Setup", SETUP_PANEL)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	setup.add_child(grid)
	_your_faction = _faction_picker("yours")
	_grid_row(grid, "Your faction", [_your_faction])
	_computer_faction = _faction_picker("computer")
	_grid_row(grid, "Computer's faction", [_computer_faction])
	_blue_faction = _faction_picker("blue")
	_red_faction = _faction_picker("red")
	_grid_row(grid, "Watched match", [_caption("Blue"), _blue_faction, _caption("Red"), _red_faction])
	_address = LineEdit.new()
	_address.placeholder_text = "e.g. 100.101.102.103"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.text = _saved_address()
	_address.text_submitted.connect(func(_t): _join())
	_grid_row(grid, "Host's address", [_address])

	# Start a game: every button that launches something, styled apart from the setup.
	var start := _section("Start a game", START_PANEL)
	var solo := _launch_group(start, "Solo", 3)
	solo.add_child(_launch_button("Play vs Computer", _play_computer, true))
	solo.add_child(_launch_button("Watch Computers", _watch))
	solo.add_child(_launch_button("Random Battle", func(): get_tree().change_scene_to_file(RANDOM_BATTLE_SCENE)))
	var online := _launch_group(start, "Online", 2)
	online.add_child(_launch_button("Host Online Match", _host))
	online.add_child(_launch_button("Join Online Match", _join))

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	column.add_child(_status)

	_cancel = Button.new()
	_cancel.text = "Cancel"
	_cancel.visible = false
	_cancel.pressed.connect(_on_cancel)
	column.add_child(_cancel)


const SETUP_PANEL := Color(0.11, 0.11, 0.14)
const START_PANEL := Color(0.10, 0.13, 0.17)
const LAUNCH := Color(0.16, 0.42, 0.62)          # launch buttons: a strong blue
const LAUNCH_MAIN := Color(0.85, 0.62, 0.18)     # Play vs Computer: gold
const LAUNCH_TEXT := Color(1, 1, 1)


## A titled panel in the menu column; returns the box to put its contents in.
func _section(heading: String, color: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	_buttons.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var label := Label.new()
	label.text = heading.to_upper()
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7))
	box.add_child(label)
	return box


## A small labelled group of launch buttons inside the Start a game panel; returns the
## row (`columns` buttons wide) to add them to.
func _launch_group(parent: VBoxContainer, heading: String, columns: int) -> GridContainer:
	var label := _caption(heading)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.78, 0.8, 0.86))
	parent.add_child(label)
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)
	return grid


## One labelled row of the setup grid.
func _grid_row(grid: GridContainer, text: String, controls: Array) -> void:
	var label := _caption(text)
	label.add_theme_color_override("font_color", Color(0.78, 0.8, 0.86))
	grid.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for control in controls:
		if control is OptionButton:
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(control)
	grid.add_child(row)


## A button that starts a game: big, filled, in the launch colour (`main`: the gold one).
func _launch_button(text: String, action: Callable, main := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	var base := LAUNCH_MAIN if main else LAUNCH
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		match state:
			"hover":
				style.bg_color = base.lightened(0.15)
			"pressed":
				style.bg_color = base.darkened(0.2)
			"focus":
				style.bg_color = base
				style.border_color = Color(1, 1, 1, 0.6)
				style.set_border_width_all(2)
			_:
				style.bg_color = base
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, LAUNCH_TEXT)
	button.pressed.connect(action)
	return button


## Computer vs computer, match after match, to watch for balance problems.
func _watch() -> void:
	MatchGame.spectating = true
	MatchGame.player_faction_choice = _picked(_blue_faction)   # Random re-rolls every match
	MatchGame.opponent_faction_choice = _picked(_red_faction)
	get_tree().change_scene_to_file(MATCH_SCENE)


func _play_computer() -> void:
	MatchGame.player_faction_choice = _picked(_your_faction)
	MatchGame.opponent_faction_choice = _picked(_computer_faction)
	get_tree().change_scene_to_file(MATCH_SCENE)


## Online: your faction goes to the other player when you connect (see Net).
func _use_your_faction_online() -> void:
	# Random is settled here, once: the other player is told a real faction.
	MatchGame.player_faction = MatchRules.resolve_faction(_picked(_your_faction))
	Net.local_faction = MatchGame.player_faction


# ---------- Faction pickers ----------

## A drop-down of every faction that has units, then Random, remembering its last choice
## under `key`.
func _faction_picker(key: String) -> OptionButton:
	var picker := OptionButton.new()
	var saved: String = _setting("factions", key, MatchRules.DEFAULT_FACTION)
	var choices := MatchRules.factions()
	choices.append(MatchRules.RANDOM_FACTION)
	for faction in choices:
		picker.add_item(faction)
		if faction == saved:
			picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(i): _save_setting("factions", key, picker.get_item_text(i)))
	return picker


func _picked(picker: OptionButton) -> String:
	if picker.selected < 0:
		return MatchRules.DEFAULT_FACTION
	return picker.get_item_text(picker.selected)


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _setting(section: String, key: String, fallback):
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return fallback
	return config.get_value(section, key, fallback)


func _save_setting(section: String, key: String, value) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(section, key, value)
	config.save(SETTINGS_PATH)


func _host() -> void:
	_use_your_faction_online()
	var error := Net.host()
	if error != OK:
		_status.text = "Couldn't host (error %d). Is another copy of the game already hosting?" % error


func _on_hosted() -> void:
	var addresses := Net.local_addresses()
	var lines := PackedStringArray(["Hosting. Waiting for your opponent to join...", ""])
	if addresses.is_empty():
		lines.append("Couldn't find this computer's address.")
	else:
		lines.append("Give them one of these addresses (a 100.x one is Tailscale's):")
		lines.append_array(addresses)
	_status.text = "\n".join(lines)
	_waiting(true)


func _join() -> void:
	var address := _address.text.strip_edges()
	if address.is_empty():
		_status.text = "Type the host's address first."
		return
	_save_address(address)
	_use_your_faction_online()
	var error := Net.join(address)
	if error != OK:
		_status.text = "Couldn't start connecting (error %d)." % error
		return
	_status.text = "Connecting to %s..." % address
	_waiting(true)


func _on_match_ready(_match_seed: int) -> void:
	get_tree().change_scene_to_file(MATCH_SCENE)


func _on_connection_failed(reason: String) -> void:
	_status.text = reason
	_waiting(false)


func _on_cancel() -> void:
	Net.leave()
	_status.text = ""
	_waiting(false)


func _waiting(on: bool) -> void:
	_buttons.visible = not on
	_cancel.visible = on


## The game was renamed (Auto Battler -> GAMBIT), which moved its user:// folder: bring the
## old menu settings (last address, faction picks) across the first time.
func _carry_over_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		return
	var old := OS.get_data_dir().path_join("Godot/app_userdata/Auto Battler/menu.cfg")
	if FileAccess.file_exists(old):
		DirAccess.copy_absolute(old, ProjectSettings.globalize_path(SETTINGS_PATH))


func _saved_address() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return ""
	return config.get_value("join", "address", "")


func _save_address(address: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("join", "address", address)
	config.save(SETTINGS_PATH)
