extends Control
## The start screen: play the computer, host an online match, join one by address, or
## open the random battle sandbox.

const MATCH_SCENE := "res://scenes/match.tscn"
const RANDOM_BATTLE_SCENE := "res://scenes/random_battle.tscn"
const SETTINGS_PATH := "user://menu.cfg"   # remembers the last address you joined
## The computer opponent's background battle tester (see AiPlanner).
const AI_EVAL_SCENE := "res://scenes/ai_eval.tscn"

var _buttons: VBoxContainer
var _address: LineEdit
var _status: Label
var _cancel: Button


func _ready() -> void:
	# A background copy started by the computer opponent to test its plans: hand straight
	# over to the tester.
	if OS.get_cmdline_user_args().has("--ai-eval"):
		get_tree().change_scene_to_file.call_deferred(AI_EVAL_SCENE)
		return
	# Testing an exported build: "AutoBattler.exe --headless -- --net-test --offline" plays
	# a match by itself (see tools/net_test.gd).
	if OS.get_cmdline_user_args().has("--net-test"):
		get_tree().change_scene_to_file.call_deferred("res://tools/net_test.tscn")
		return
	# Back to plain offline play, whatever state the last match left things in.
	Net.leave()
	BattleUnit.view_rotation = 0.0
	BattleUnit.swap_team_colors = false
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
	column.custom_minimum_size = Vector2(380, 0)
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)

	var title := Label.new()
	title.text = "Auto Battler"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	column.add_child(_buttons)
	_button("Play vs Computer", func(): get_tree().change_scene_to_file(MATCH_SCENE))
	_button("Host online match", _host)

	var join_row := HBoxContainer.new()
	_address = LineEdit.new()
	_address.placeholder_text = "Host's address (e.g. 100.101.102.103)"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.text = _saved_address()
	_address.text_submitted.connect(func(_t): _join())
	join_row.add_child(_address)
	var join := Button.new()
	join.text = "Join"
	join.pressed.connect(_join)
	join_row.add_child(join)
	_buttons.add_child(join_row)

	_button("Random battle", func(): get_tree().change_scene_to_file(RANDOM_BATTLE_SCENE))

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	column.add_child(_status)

	_cancel = Button.new()
	_cancel.text = "Cancel"
	_cancel.visible = false
	_cancel.pressed.connect(_on_cancel)
	column.add_child(_cancel)


func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(action)
	_buttons.add_child(button)


func _host() -> void:
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
