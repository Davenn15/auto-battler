class_name DamageTracker
extends PanelContainer
## A damage meter: each team's units ranked by damage dealt (or healing, or shielding),
## one bar each, biggest at the top. In Damage mode each bar is split into Might, Insight
## and Celerity, sized by how much of each type that unit dealt. Bars are scaled to the
## highest total on either team, so the two columns can be compared.

const TEAM_NAMES := {1: "Team 1", 2: "Team 2"}
const TEAM_COLORS := {
	1: Color(0.4, 0.65, 1.0),   # blue
	2: Color(1.0, 0.4, 0.4),    # red
}

const MODES := {"damage": "Damage", "healing": "Healing", "shielding": "Shielding"}
const MODE_COLORS := {"healing": Color(0.35, 0.8, 0.4), "shielding": Color(0.85, 0.9, 0.95)}

const FRAME_COLOR := Color(0.09, 0.09, 0.11, 0.92)
const BORDER_COLOR := Color(0.38, 0.38, 0.44)
const COLUMN_WIDTH := 190.0

var _stats: Dictionary = {}     # unit instance id -> {name, team, damage, healing, shielding, types}
var _columns: Dictionary = {}   # team -> VBoxContainer of MeterRows
var _titles: Dictionary = {}    # team -> its column's title Label
var _waiting: Label
var _legend: HBoxContainer
var _mode: String = "damage"
var _dirty: bool = false


func _ready() -> void:
	add_to_group("damage_tracker")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _frame_style())
	# Top-right corner, growing left and down as the meter fills.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
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
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_set_mode.bind(mode))
		tabs.add_child(button)

	_waiting = Label.new()
	_waiting.text = "Appears once the fight starts."
	_waiting.add_theme_font_size_override("font_size", 12)
	_waiting.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
	layout.add_child(_waiting)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	layout.add_child(row)
	for team in TEAM_COLORS:
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
		column.add_theme_constant_override("separation", 2)
		var title := Label.new()
		title.text = TEAM_NAMES.get(team, "Team %d" % team)
		title.add_theme_color_override("font_color", TEAM_COLORS[team])
		title.add_theme_font_size_override("font_size", 13)
		column.add_child(title)
		row.add_child(column)
		_columns[team] = column
		_titles[team] = title

	_legend = HBoxContainer.new()
	_legend.add_theme_constant_override("separation", 10)
	for damage_type in Stats.DAMAGE_TYPE_COLORS:
		_legend.add_child(_legend_entry(Stats.DAMAGE_TYPE_NAMES[damage_type], Stats.DAMAGE_TYPE_COLORS[damage_type]))
	layout.add_child(_legend)
	_refresh()


func _frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = FRAME_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	return style


## A small coloured square and a name, for the key under the bars.
func _legend_entry(text: String, color: Color) -> HBoxContainer:
	var entry := HBoxContainer.new()
	entry.add_theme_constant_override("separation", 4)
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(10, 10)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	entry.add_child(swatch)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	entry.add_child(label)
	return entry


## Clears old numbers. Call once at the start of a battle.
## Renames the columns (e.g. {1: "You", 2: "Opponent"}); with `swap_colors` team 1 shows
## red and team 2 blue, for when the local player is team 2.
func set_team_titles(names: Dictionary, swap_colors: bool = false) -> void:
	for team in _titles:
		var title: Label = _titles[team]
		title.text = names.get(team, TEAM_NAMES.get(team, "Team %d" % team))
		var shown: int = (3 - team) if swap_colors else team
		title.add_theme_color_override("font_color", TEAM_COLORS.get(shown, Color.WHITE))


func reset() -> void:
	_stats.clear()
	_refresh()


## Adds a unit to the meter (at 0) so it shows even if it never deals damage.
func register(unit: BattleUnit) -> void:
	var unit_name: String = unit.data.display_name.capitalize() if unit.data != null else str(unit.name)
	_stats[unit.get_instance_id()] = {"name": unit_name, "team": unit.team, "damage": 0.0,
			"healing": 0.0, "shielding": 0.0, "types": {}}
	_refresh()


func record_damage(unit_id: int, amount: float) -> void:
	var entry = _stats.get(unit_id)
	if entry != null:
		# Every damage report comes straight after the hit, so this is that hit's type.
		var damage_type := BattleUnit.last_damage_type
		entry["types"][damage_type] = entry["types"].get(damage_type, 0.0) + amount
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


## Rebuilds both columns: rows sorted biggest first, every bar scaled to the top total.
func _refresh() -> void:
	_waiting.visible = _stats.is_empty()
	_legend.visible = _mode == "damage" and not _stats.is_empty()
	var top := 1.0
	for entry in _stats.values():
		top = maxf(top, entry[_mode])
	for team in _columns:
		var column: VBoxContainer = _columns[team]
		var rows: Array = _stats.values().filter(func(e): return e["team"] == team)
		rows.sort_custom(func(a, b): return a[_mode] > b[_mode])
		# Reuse the row nodes already there; add or remove only what's needed.
		var needed := rows.size() + 1   # +1 for the team title
		while column.get_child_count() > needed:
			var extra := column.get_child(column.get_child_count() - 1)
			column.remove_child(extra)
			extra.queue_free()
		while column.get_child_count() < needed:
			column.add_child(MeterRow.new())
		for i in rows.size():
			(column.get_child(i + 1) as MeterRow).show_entry(rows[i], _mode, top)


## One bar: the unit's name on the left, its total on the right, over a bar whose length
## is its share of the top total. In Damage mode the bar is split by damage type.
class MeterRow extends Control:
	const HEIGHT := 16.0
	const FONT_SIZE := 11
	const TRACK_COLOR := Color(1, 1, 1, 0.06)

	var _name: String = ""
	var _total: float = 0.0
	var _segments: Array = []   # [length fraction of the full width, color]

	func _init() -> void:
		custom_minimum_size = Vector2(0, HEIGHT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_entry(entry: Dictionary, mode: String, top: float) -> void:
		_name = entry["name"]
		_total = entry[mode]
		_segments.clear()
		if mode == "damage":
			for damage_type in Stats.DAMAGE_TYPE_COLORS:   # same order every time: Might, Insight, Celerity
				var amount: float = entry["types"].get(damage_type, 0.0)
				if amount > 0.0:
					_segments.append([amount / top, Stats.DAMAGE_TYPE_COLORS[damage_type]])
		elif _total > 0.0:
			_segments.append([_total / top, DamageTracker.MODE_COLORS[mode]])
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), TRACK_COLOR)
		var x := 0.0
		for segment in _segments:
			var width: float = segment[0] * size.x
			draw_rect(Rect2(x, 1.0, width, size.y - 2.0), segment[1])
			x += width
		var font := ThemeDB.fallback_font
		var baseline := (size.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) / 2.0
		_draw_shadowed(font, Vector2(4, baseline), _name, HORIZONTAL_ALIGNMENT_LEFT)
		_draw_shadowed(font, Vector2(4, baseline), str(roundi(_total)), HORIZONTAL_ALIGNMENT_RIGHT)

	## White text with a dark outline, readable over any bar colour.
	func _draw_shadowed(font: Font, pos: Vector2, text: String, align: HorizontalAlignment) -> void:
		var width := size.x - 8.0
		draw_string_outline(font, pos, text, align, width, FONT_SIZE, 3, Color(0, 0, 0, 0.85))
		draw_string(font, pos, text, align, width, FONT_SIZE, Color.WHITE)
