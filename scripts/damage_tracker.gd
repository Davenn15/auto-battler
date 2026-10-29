class_name DamageTracker
extends PanelContainer
## Shows total damage dealt by each unit, one column per team.

const TEAM_NAMES := {1: "Team 1", 2: "Team 2"}
const TEAM_COLORS := {
	1: Color(0.4, 0.65, 1.0),   # blue
	2: Color(1.0, 0.4, 0.4),    # red
}

const MODES := {"damage": "Damage", "healing": "Healing", "shielding": "Shielding"}


var _stats: Dictionary = {}     # unit instance id -> {name, team, damage}
var _columns: Dictionary = {}   # team -> Label
var _mode: String = "damage"
var _dirty: bool = false

func _ready() -> void:
	add_to_group("damage_tracker")
	visible = false   # appears when a battle starts
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var layout := VBoxContainer.new()
	add_child(layout)

	# Tab buttons: only one can be pressed at a time.
	var tabs := HBoxContainer.new()
	layout.add_child(tabs)
	var group := ButtonGroup.new()
	for mode in MODES:
		var button := Button.new()
		button.text = MODES[mode]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = (mode == _mode)
		button.pressed.connect(_set_mode.bind(mode))
		tabs.add_child(button)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	layout.add_child(row)

	for team in TEAM_COLORS:
		var label := Label.new()
		label.add_theme_color_override("font_color", TEAM_COLORS[team])
		row.add_child(label)
		_columns[team] = label


## Clears old numbers and shows the panel. Call once at the start of a battle.
func reset() -> void:
	_stats.clear()
	visible = true
	_refresh()


## Adds a unit to the list (at 0 damage) and starts listening to its attacks.
func register(unit: BattleUnit) -> void:
	var unit_name: String = unit.data.display_name if unit.data != null else str(unit.name)
	_stats[unit.get_instance_id()] = {"name": unit_name, "team": unit.team, "damage": 0.0, "healing": 0.0, "shielding": 0.0}
	_refresh()


func record_damage(unit_id: int, amount: float) -> void:
	_add_stat(unit_id, "damage", amount)


func record_healing(unit_id: int, amount: float) -> void:
	_add_stat(unit_id, "healing", amount)


func record_shielding(unit_id: int, amount: float) -> void:
	_add_stat(unit_id, "shielding", amount)


func _add_stat(unit_id: int, key: String, amount: float) -> void:
	var entry = _stats.get(unit_id)
	if entry == null:
		return
	entry[key] += amount
	if key == _mode:
		_dirty = true   # redraw once per frame, not once per record


func _set_mode(mode: String) -> void:
	_mode = mode
	_refresh()


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_refresh()


func _refresh() -> void:
	for team in _columns:
		var rows: Array = []
		for entry in _stats.values():
			if entry["team"] == team:
				rows.append(entry)
			rows.sort_custom(func(a, b): return a[_mode] > b[_mode])

		var lines := PackedStringArray([TEAM_NAMES.get(team, "Team %d" % team)])
		for entry in rows:
			lines.append("%s: %d" % [entry["name"], roundi(entry[_mode])])
		_columns[team].text = "\n".join(lines)
