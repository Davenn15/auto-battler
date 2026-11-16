class_name DevPanel
extends PanelContainer
## A testing panel for matches against the computer, only when the game is run from the
## Godot editor (players never see it). F1 shows or hides it. It can give you Aura and
## Reserve, fully upgrade the unit shown in the unit info panel, clear your Ascensions,
## and open an Encounter offering any one Ascension (the normal pick flow, returning to
## the same planning phase afterwards).

var game: MatchGame
var _ascensions: Array[Ascension] = []
var _picker: OptionButton
var _status: Label


## True when the panel should exist at all: run from the editor, offline, not watching.
static func available() -> bool:
	return OS.has_feature("editor") and not Net.is_online() and not MatchGame.spectating


func _init(p_game: MatchGame) -> void:
	game = p_game


func _ready() -> void:
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.06, 0.06, 0.95)
	style.border_color = Color(1.0, 0.45, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	position = Vector2(330, 40)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var title := Label.new()
	title.text = "Test panel (F1)"
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
	column.add_child(title)

	var money := HBoxContainer.new()
	column.add_child(money)
	money.add_child(_button("+20 Aura", func(): _give(20, 0)))
	money.add_child(_button("+20 Reserve", func(): _give(0, 20)))
	column.add_child(_button("Fully upgrade the selected unit", _max_selected))
	column.add_child(_button("Clear my Ascensions", _clear_ascensions))

	_picker = OptionButton.new()
	_picker.fit_to_longest_item = false
	_picker.custom_minimum_size = Vector2(300, 0)
	for faction in [""] + Array(MatchRules.factions()):
		for ascension in MatchRules.ascension_pool(faction):
			_ascensions.append(ascension)
			_picker.add_item("%s T%s · %s%s" % ["Neutral" if faction == "" else faction, ascension.tier_text(),
					ascension.get_display_name(), "  (pick a unit)" if ascension.is_chosen() else ""])
	column.add_child(_picker)
	column.add_child(_button("Offer it in an Encounter", _offer))
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	column.add_child(_status)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F1:
		visible = not visible
		get_viewport().set_input_as_handled()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


func _planning() -> bool:
	if game.phase != MatchGame.Phase.PLANNING:
		_status.text = "Only during planning."
		return false
	return true


func _give(aura: int, reserve: int) -> void:
	game.player.aura += aura
	game.player.reserve += reserve
	game.changed()


## Takes the unit shown in the unit info panel to its last upgrade level, picking the first
## choice at each level it doesn't have yet.
func _max_selected() -> void:
	if not _planning():
		return
	var shown := game.unit_info.get_unit()
	var index: int = shown.get_meta("army_index", -1) if shown != null and shown.team == MatchGame.PLAYER_TEAM else -1
	if index < 0 or index >= game.player.units.size():
		_status.text = "Click one of your units first."
		return
	var unit := game.player.units[index]
	while unit.level() < MatchRules.max_level(unit.data):
		unit.path.append(0)
	_status.text = "%s is now %s." % [unit.display_name(), unit.label().strip_edges()]
	game.changed()


func _clear_ascensions() -> void:
	game.player.ascensions.clear()
	for unit in game.player.units:
		unit.ascensions.clear()
	_status.text = "Ascensions cleared."
	game.changed()


func _offer() -> void:
	if not _planning() or _picker.selected < 0:
		return
	var ascension := _ascensions[_picker.selected]
	if ascension.is_chosen() and not game.player.units.any(func(u): return ascension.can_pick(u)):
		_status.text = "None of your units can take it yet."
		return
	_status.text = ""
	visible = false
	game.dev_offer_ascension(ascension)
