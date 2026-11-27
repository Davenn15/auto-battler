class_name Glossary
extends Control
## The glossary: a window over the main menu (which stays put, shaded behind it) covering
## most of the screen. Every faction side by side, each in a panel in its board-border
## colour, with its units in rows by tier (sprite and name). Built from the same rosters
## the shop uses, so new units show up on their own. More information is meant to be added
## later. Close it with Close, Escape, or a click on the shade around it.
## Hovering a unit lights a bar in its faction's colour under its portrait; clicking it opens
## a details panel on the right (base stats, passive, Gambit and every upgrade), and the
## faction lists shrink to make room.

const SHADE := Color(0, 0, 0, 0.6)
const WINDOW_COLOR := Color(0.09, 0.09, 0.11, 0.98)
const WINDOW_BORDER := Color(0.38, 0.38, 0.44)
## Share of the screen left around the window on each side (0.05 = 5%).
const WINDOW_INSET := 0.05
const PANEL_COLOR := Color(0.12, 0.12, 0.15)
const OTHER_FACTION_COLOR := Color(0.7, 0.7, 0.76)   # a faction with no border colour yet
const TIER_COLOR := Color(0.6, 0.6, 0.68)
const NAME_COLOR := Color(0.85, 0.85, 0.9)
const SPRITE_SIZE := 56
const TILE_WIDTH := 84
## Tile sizes while the details panel is open, so everything fits beside it.
const COMPACT_SPRITE_SIZE := 36
const COMPACT_TILE_WIDTH := 50
const GLOW_HEIGHT := 4.0
## The details panel is at least this wide and takes whatever room the lists leave.
const DETAIL_WIDTH := 360.0
const LABEL_COLOR := "9a9aa8"

var _factions_box: HBoxContainer
var _factions_scroll: ScrollContainer
var _detail: PanelContainer
var _detail_text: RichTextLabel
var _detail_picture: TextureRect
var _selected: UnitData = null

## Called when the window closes.
var on_back: Callable


func _init(back: Callable = Callable()) -> void:
	on_back = back


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The shade over the whole menu; it also catches clicks, so the menu can't be used
	# while the glossary is open, and a click on it closes the glossary.
	var shade := ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(event: InputEvent):
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_back())
	add_child(shade)

	var window := PanelContainer.new()
	window.anchor_left = WINDOW_INSET
	window.anchor_top = WINDOW_INSET
	window.anchor_right = 1.0 - WINDOW_INSET
	window.anchor_bottom = 1.0 - WINDOW_INSET
	window.offset_left = 0
	window.offset_top = 0
	window.offset_right = 0
	window.offset_bottom = 0
	window.mouse_filter = Control.MOUSE_FILTER_STOP   # clicks inside don't reach the shade
	var style := StyleBoxFlat.new()
	style.bg_color = WINDOW_COLOR
	style.border_color = WINDOW_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	window.add_theme_stylebox_override("panel", style)
	add_child(window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	window.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Glossary"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(110, 40)
	close.add_theme_font_size_override("font_size", 17)
	close.pressed.connect(_back)
	header.add_child(close)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_factions_scroll = scroll
	_factions_box = HBoxContainer.new()
	_factions_box.add_theme_constant_override("separation", 16)
	_factions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_factions_box)
	_build_detail(body)
	_rebuild_factions()


## (Re)builds the faction panels: full-size tiles, or compact ones while the details panel
## is open.
func _rebuild_factions() -> void:
	# With the details open, the lists take only the room they need and the panel the rest.
	_factions_scroll.size_flags_horizontal = Control.SIZE_FILL if _selected != null else Control.SIZE_EXPAND_FILL
	for child in _factions_box.get_children():
		_factions_box.remove_child(child)   # now, so the old panels don't count toward the size
		child.queue_free()
	for faction in MatchRules.factions():
		_factions_box.add_child(_faction_panel(faction))


## One faction's panel: its name in its colour, then a row of units for each tier.
func _faction_panel(faction: String) -> Control:
	var color: Color = BattleGrid.FACTION_BORDER_COLORS.get(faction, OTHER_FACTION_COLOR)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = faction
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", color)
	box.add_child(heading)
	var by_tier := {}
	for data in MatchRules.roster_for(faction):
		if not by_tier.has(data.tier):
			by_tier[data.tier] = []
		by_tier[data.tier].append(data)
	var tiers := by_tier.keys()
	tiers.sort()
	for tier in tiers:
		var units: Array = by_tier[tier]
		units.sort_custom(func(a, b): return a.get_title().to_lower() < b.get_title().to_lower())
		box.add_child(_tier_row(tier, units))
	return panel


## "T1" and that tier's units, each as its sprite over its name.
func _tier_row(tier: int, units: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4 if _selected != null else 6)
	var label := Label.new()
	label.text = "T%d" % tier
	label.custom_minimum_size = Vector2(26 if _selected != null else 32, 0)
	label.add_theme_color_override("font_color", TIER_COLOR)
	label.add_theme_font_size_override("font_size", 16)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	for data in units:
		row.add_child(_unit_tile(data))
	return row


## A unit's portrait and name. Hovering it lights a bar in its faction's colour under the
## portrait (it stays lit while the unit is shown in the details panel); clicking it shows
## the unit's details.
func _unit_tile(data: UnitData) -> Control:
	var compact := _selected != null
	var color: Color = BattleGrid.FACTION_BORDER_COLORS.get(MatchRules.faction_of(data), OTHER_FACTION_COLOR)
	var tile := VBoxContainer.new()
	tile.custom_minimum_size = Vector2(COMPACT_TILE_WIDTH if compact else TILE_WIDTH, 0)
	tile.add_theme_constant_override("separation", 2)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.tooltip_text = ""
	var picture := TextureRect.new()
	picture.texture = data.sprite
	var size_px := COMPACT_SPRITE_SIZE if compact else SPRITE_SIZE
	picture.custom_minimum_size = Vector2(size_px, size_px)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel art
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(picture)
	var glow := ColorRect.new()
	glow.color = color
	glow.custom_minimum_size = Vector2(0, GLOW_HEIGHT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate.a = 1.0 if data == _selected else 0.0
	tile.add_child(glow)
	var name_label := Label.new()
	name_label.text = data.get_title()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", NAME_COLOR)
	name_label.add_theme_font_size_override("font_size", 11 if compact else 13)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS   # long names end in "…" in compact tiles
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(name_label)
	tile.mouse_entered.connect(func(): glow.modulate.a = 1.0)
	tile.mouse_exited.connect(func(): glow.modulate.a = 1.0 if data == _selected else 0.0)
	tile.gui_input.connect(func(event: InputEvent):
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_show_detail(data))
	return tile


# ---------- The details panel ----------

func _build_detail(parent: Control) -> void:
	_detail = PanelContainer.new()
	_detail.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = WINDOW_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	_detail.add_theme_stylebox_override("panel", style)
	parent.add_child(_detail)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_detail.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	column.add_child(top)
	_detail_picture = TextureRect.new()
	_detail_picture.custom_minimum_size = Vector2(80, 80)
	_detail_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(_detail_picture)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var close := Button.new()
	close.text = "Close"
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(_hide_detail)
	top.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_detail_text = RichTextLabel.new()
	_detail_text.bbcode_enabled = true
	_detail_text.fit_content = true
	_detail_text.scroll_active = false
	_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_text.add_theme_font_size_override("normal_font_size", 14)
	_detail_text.add_theme_font_size_override("bold_font_size", 14)
	scroll.add_child(_detail_text)


func _show_detail(data: UnitData) -> void:
	_selected = data
	_detail_picture.texture = data.sprite
	_detail_text.text = describe(data)
	Keyphrases.style_label(_detail_text, 14)
	_detail.visible = true
	_rebuild_factions()   # compact tiles (first time) and the glow on the new pick


func _hide_detail() -> void:
	_selected = null
	_detail.visible = false
	_rebuild_factions()


## Everything the details panel shows about `data`, as BBCode: name, faction and tier, base
## stats (before upgrades, buffs and Keepsakes), passives, Gambit, and both upgrade paths
## with every upgrade's description and numbers.
static func describe(data: UnitData) -> String:
	var faction := MatchRules.faction_of(data)
	var color: Color = BattleGrid.FACTION_BORDER_COLORS.get(faction, OTHER_FACTION_COLOR)
	var lines := PackedStringArray()
	lines.append("[font_size=24][color=#%s]%s[/color][/font_size]" % [color.to_html(false), data.get_title()])
	lines.append("[color=#%s]%s · Tier %d[/color]" % [LABEL_COLOR, faction, data.tier])
	lines.append("")
	lines.append("[b]Base stats[/b]")
	var stat_line := func(stat: Stats.Stat) -> String:
		return "%s %d" % [Stats.STAT_NAMES.get(stat, str(stat)), roundi(data.get_base_stat(stat) * Stats.tier_multiplier(stat, data.tier))]
	lines.append("Health %d" % roundi(data.max_health * Stats.tier_health_multiplier(data.tier)))
	lines.append("%s   %s   %s" % [stat_line.call(Stats.Stat.MIGHT), stat_line.call(Stats.Stat.INSIGHT), stat_line.call(Stats.Stat.CELERITY)])
	lines.append("%s   %s   %s" % [stat_line.call(Stats.Stat.MIGHT_WARD), stat_line.call(Stats.Stat.INSIGHT_WARD), stat_line.call(Stats.Stat.CELERITY_WARD)])
	lines.append("Attack range %d   Charge %d / %d   Regeneration %s" % [data.attack_range_cells, roundi(data.starting_charge), roundi(data.max_charge), str(data.health_regen)])
	lines.append("")
	for passive in data.passives:
		if passive == null:
			continue
		lines.append(MatchHud._ability_text("Passive", UnitInfoPanel._ability_name(passive, passive.passive_name, "Passive"), passive.description,
				DescriptionContext.of(passive).with_base_stats(data, 0, 0, false)))
	if data.gambit != null:
		lines.append(MatchHud._ability_text("Gambit", UnitInfoPanel._ability_name(data.gambit, data.gambit.gambit_name, "Gambit"), data.gambit.description,
				DescriptionContext.of(data.gambit).with_base_stats(data, 0, 0, true)))
	var paths := ["A", "B"]
	for i in data.upgrades.size():
		var path_upgrade: Upgrade = data.upgrades[i]
		var letter: String = paths[i] if i < paths.size() else str(i + 1)
		lines.append("")
		lines.append("[b][color=#%s]Path %s: %s[/color][/b]" % [color.to_html(false), letter, path_upgrade.upgrade_name])
		lines.append(_upgrade_text(data, [i], path_upgrade))
		for j in path_upgrade.next_choices.size():
			lines.append("[b]%s%d[/b]  %s" % [letter, j + 1, _upgrade_text(data, [i, j], path_upgrade.next_choices[j])])
	return "\n".join(lines)


static func _upgrade_text(data: UnitData, path: Array, upgrade: Upgrade) -> String:
	if upgrade == null or upgrade.description == "":
		return ""
	return "[color=#cccccc]%s[/color]" % Keyphrases.format(upgrade.description, DescriptionContext.for_upgrade(data, path))


func _back() -> void:
	if on_back.is_valid():
		on_back.call()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back()
