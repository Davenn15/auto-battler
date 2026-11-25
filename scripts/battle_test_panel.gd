class_name BattleTestPanel
extends PanelContainer
## A testing panel for the random battle, only when the game is run from the Godot editor.
## F1 shows or hides it. Before the fight starts, it can fully upgrade the unit shown in
## the unit info panel, give it any Ascension (a chosen-unit one goes to that unit; an
## army-wide one to every unit on its team), and clear all Ascensions.

var unit_info: UnitInfoPanel
var battle_manager: BattleManager
var _ascensions: Array[Ascension] = []
var _picker: OptionButton
var _status: Label


static func available() -> bool:
	return OS.has_feature("editor")


func _init(p_unit_info: UnitInfoPanel, p_battle_manager: BattleManager) -> void:
	unit_info = p_unit_info
	battle_manager = p_battle_manager


func _ready() -> void:
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.06, 0.06, 0.95)
	style.border_color = Color(1.0, 0.45, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	position = Vector2(330, 8)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var title := Label.new()
	title.text = "Test panel (F1): click a unit, then…"
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
	column.add_child(title)
	column.add_child(_button("Fully upgrade it", _max_selected))
	_picker = OptionButton.new()
	_picker.fit_to_longest_item = false
	_picker.custom_minimum_size = Vector2(300, 0)
	for faction in [""] + Array(MatchRules.factions()):
		for ascension in MatchRules.ascension_pool(faction):
			_ascensions.append(ascension)
			_picker.add_item("%s T%s · %s%s" % ["Neutral" if faction == "" else faction, ascension.tier_text(),
					ascension.get_display_name(), "  (this unit)" if ascension.is_chosen() else "  (its team)"])
	column.add_child(_picker)
	column.add_child(_button("Give it this Ascension", _give))
	column.add_child(_button("Clear all Ascensions", _clear))
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


## The unit shown in the unit info panel, while the fight hasn't started; null otherwise.
func _selected() -> BattleUnit:
	if battle_manager.phase != BattleManager.Phase.PREP:
		_status.text = "Only before the fight starts."
		return null
	var unit := unit_info.get_unit()
	if unit == null or unit.is_summon:
		_status.text = "Click a unit first."
		return null
	return unit


func _max_selected() -> void:
	var unit := _selected()
	if unit == null:
		return
	while unit.upgrade_path.size() < MatchRules.max_level(unit.data):
		unit.upgrade_path.append(0)
	unit.refresh_setup()
	_status.text = "%s is now %s." % [unit.data.get_title(), RandomTeams.path_label(unit.upgrade_path)]


func _give() -> void:
	var unit := _selected()
	if unit == null or _picker.selected < 0:
		return
	var ascension := _ascensions[_picker.selected]
	if ascension.is_chosen():
		var as_army := ArmyUnit.new(unit.data)
		as_army.path.assign(unit.upgrade_path)
		if not ascension.can_pick(as_army):
			_status.text = "%s can't take %s." % [unit.data.get_title(), ascension.get_display_name()]
			return
		unit.ascensions.append(ascension)
		unit.refresh_setup()
		_status.text = "%s gave %s." % [ascension.get_display_name(), unit.data.get_title()]
		return
	for node in unit.get_tree().get_nodes_in_group("units"):
		var ally := node as BattleUnit
		if ally != null and ally.team == unit.team and not ally.is_summon:
			ally.ascensions.append(ascension)
			ally.refresh_setup()
	_status.text = "Team %d took %s." % [unit.team, ascension.get_display_name()]


func _clear() -> void:
	if battle_manager.phase != BattleManager.Phase.PREP:
		_status.text = "Only before the fight starts."
		return
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and not unit.ascensions.is_empty():
			unit.ascensions.clear()
			unit.refresh_setup()
	_status.text = "Ascensions cleared."
