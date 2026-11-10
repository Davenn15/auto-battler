class_name LineupPanel
extends PanelContainer
## A framed panel listing both teams, each in its own colour: team 2 on top and team 1
## below, the same way round as the battlefield. Each team shows its ARV and every unit's
## upgrade path and items. Reads the units on the board a few times a second, so it keeps
## up with the item toolbox and with units dying. Collapses to just its header.

const WIDTH := 460.0
const REFRESH_TIME := 0.25   # seconds between rereading the board
const FRAME_COLOR := Color(0.09, 0.09, 0.11, 0.92)
const BORDER_COLOR := Color(0.38, 0.38, 0.44)
const ITEM_COLOR := Color(0.7, 0.7, 0.72)
const DEAD_COLOR := Color(0.45, 0.45, 0.45)

var _title: Label
var _toggle: Button
var _body: VBoxContainer
var _message: Label        # errors, or the result once the battle ends
var _team_text: Dictionary = {}   # team -> RichTextLabel
var _refresh_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # clicks on the panel don't reach the board
	add_theme_stylebox_override("panel", _frame_style())
	# Sit in the bottom-left corner and grow upward as the content needs.
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 8)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(WIDTH, 0)
	_build()


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0 and _body.visible:
		_refresh_left = REFRESH_TIME
		_refresh_teams()


## The header line, e.g. "ARV 48    seed 7".
func set_header(text: String) -> void:
	_title.text = text


## A line under the teams: an error, or who won. Empty hides it.
func set_message(text: String, color: Color = Color.WHITE) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", color)
	_message.visible = text != ""


# ---------- Building ----------

func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.text = "Lineups"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_toggle = Button.new()
	_toggle.text = "Show"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.pressed.connect(_on_toggle_pressed)
	header.add_child(_toggle)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	column.add_child(_body)
	_body.visible = false   # starts minimized; Show opens it
	for team in [2, 1]:   # team 2 starts at the top of the board
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", _team_style(_team_color(team)))
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_theme_font_size_override("normal_font_size", 13)
		text.add_theme_font_size_override("bold_font_size", 13)
		box.add_child(text)
		_body.add_child(box)
		_team_text[team] = text
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.visible = false
	_body.add_child(_message)


func _frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = FRAME_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	return style


## A tinted box with a thick stripe of the team's colour down its left side.
func _team_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.14)
	style.border_color = color
	style.border_width_left = 4
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func _team_color(team: int) -> Color:
	return DamageTracker.TEAM_COLORS.get(team, Color.WHITE)


func _on_toggle_pressed() -> void:
	_body.visible = not _body.visible
	_toggle.text = "Hide" if _body.visible else "Show"
	if _body.visible:
		_refresh_teams()


# ---------- Filling in the teams ----------

## Every unit this panel has seen, in the order it first saw them, so units that die and
## leave the board stay listed (struck through) and still count toward their team's ARV.
## Each entry: {id, team, text, aura, reserve, alive}.
## "New teams" reloads the whole scene, which starts this list fresh.
var _seen: Array[Dictionary] = []


func _refresh_teams() -> void:
	# Update what's on the board now; anything missing has died and been removed.
	var on_board := {}
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit.is_summon or unit.data == null:
			continue
		on_board[unit.get_instance_id()] = unit
	var known := {}
	for record in _seen:
		known[record["id"]] = record
		if not on_board.has(record["id"]):
			record["alive"] = false
	for id in on_board:
		var unit: BattleUnit = on_board[id]
		if not known.has(id):
			var record := {"id": id}
			_seen.append(record)
			known[id] = record
		var record: Dictionary = known[id]
		record["team"] = unit.team
		record["text"] = _unit_entry(unit)
		record["aura"] = unit.get_aura_value()
		record["reserve"] = unit.get_reserve_value()
		record["alive"] = unit.alive

	for team in _team_text:
		var color := _team_color(team)
		var aura := 0
		var reserve := 0
		var entries: PackedStringArray = []
		for record in _seen:
			if record["team"] != team:
				continue
			aura += record["aura"]
			reserve += record["reserve"]
			var text: String = record["text"]
			if not record["alive"]:
				text = "[s][color=#%s]%s[/color][/s]" % [DEAD_COLOR.to_html(false), _strip_colors(text)]
			entries.append(text)
		var lines: PackedStringArray = ["[b][color=#%s]%s[/color][/b]   ARV %d   [color=#%s](Aura %d, Reserve %d)[/color]" % [
				color.to_html(false), DamageTracker.TEAM_NAMES.get(team, "Team %d" % team),
				maxi(aura, reserve), ITEM_COLOR.to_html(false), aura, reserve]]
		lines.append("\u00a0\u00a0·   ".join(entries) if not entries.is_empty() else "[color=#%s]No units[/color]" % DEAD_COLOR.to_html(false))
		_team_text[team].text = "\n".join(lines)


## "Garth A1 (Crusher, Might Shard)": name and path, items in grey. The name and path are
## joined by a non-breaking space so they never wrap apart.
func _unit_entry(unit: BattleUnit) -> String:
	var name_text := unit.data.display_name.capitalize().replace(" ", "\u00a0")
	var entry := "%s\u00a0[b]%s[/b]" % [name_text, RandomTeams.path_label(unit.upgrade_path)]
	if not unit.keepsakes.is_empty():
		var items := PackedStringArray(unit.keepsakes.map(func(k): return k.get_display_name()))
		entry += " [color=#%s](%s)[/color]" % [ITEM_COLOR.to_html(false), ", ".join(items)]
	return entry


## Takes out [color] tags, so a dead unit's whole entry turns grey.
static func _strip_colors(text: String) -> String:
	var regex := RegEx.create_from_string("\\[/?color[^\\]]*\\]")
	return regex.sub(text, "", true)
