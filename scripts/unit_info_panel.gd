class_name UnitInfoPanel
extends PanelContainer
## Click a unit to show its name, upgrades, live stats and abilities. It stays up until you
## click another unit or empty ground. Refreshes every frame while open, so buffs and
## damage show as they happen. In a match the board is rebuilt after every change; the
## panel then follows the same unit to its new copy.
##
## Stats and abilities are on two tabs, and the panel always fits on screen (between
## top_reserve and bottom_reserve): if a unit's text is still too long, its font shrinks.

const PICK_RADIUS := 30.0   # how close to a unit's centre a click must be, in pixels
const MARKER_COLOR := Color(1.0, 0.85, 0.3, 0.9)   # gold ring under the selected unit
const MARKER_RADIUS := 26.0
const WIDTH := 310.0

const FRAME_COLOR := Color(0.09, 0.09, 0.11, 0.94)
const BORDER_COLOR := Color(0.38, 0.38, 0.44)
const DIM := "#9a9aa5"          # labels and secondary text
const DESCRIPTION := "#c8c8d0"  # ability descriptions
const UP := "#7fdc7f"           # a stat above its base
const DOWN := "#ff7a7a"         # a stat below its base
const HEALTH_COLOR := Color(0.42, 0.75, 0.35)
const SHIELD_COLOR := Color(0.75, 0.85, 1.0)
const CHARGE_COLOR := BattleUnit.CHARGE_COLOR   # purple, same as the bar over each unit

## Stats that a Shard gives, drawn in that Shard's colour.
const STAT_SHARDS := {
	Stats.Stat.MIGHT: Shard.Kind.MIGHT,
	Stats.Stat.INSIGHT: Shard.Kind.INSIGHT,
	Stats.Stat.CELERITY: Shard.Kind.CELERITY,
	Stats.Stat.MIGHT_WARD: Shard.Kind.MIGHT_WARD,
	Stats.Stat.INSIGHT_WARD: Shard.Kind.INSIGHT_WARD,
	Stats.Stat.CELERITY_WARD: Shard.Kind.CELERITY_WARD,
	Stats.Stat.WRACK_CHANCE: Shard.Kind.WRACK,
	Stats.Stat.WRACK_DAMAGE: Shard.Kind.WRACK,
}
## The stat table: each row is an attribute beside the ward against it.
const STAT_ROWS := [
	[Stats.Stat.MIGHT, Stats.Stat.MIGHT_WARD],
	[Stats.Stat.INSIGHT, Stats.Stat.INSIGHT_WARD],
	[Stats.Stat.CELERITY, Stats.Stat.CELERITY_WARD],
	[Stats.Stat.WRACK_CHANCE, Stats.Stat.WRACK_DAMAGE],
]

## Sent whenever the selected unit changes (null when the panel closes). The item toolbox
## uses it to know which unit to equip.
signal unit_selected(unit: BattleUnit)

var _unit: BattleUnit = null
var _team := 0
var _army_index := -1   # in a match, which army unit this is, to find it after a rebuild
var _portrait: TextureRect
var _title: RichTextLabel
var _health_bar: ProgressBar
var _health_text: Label
var _charge_bar: ProgressBar
var _charge_text: Label
var _text: RichTextLabel
var _marker: Line2D   # the ring under the selected unit; a child of that unit

## Screen space kept free above and below the panel (the top bar, a log...).
@export var top_reserve := 40.0
@export var bottom_reserve := 8.0
## Filled by whoever owns the screen (the match HUD puts the unit's items here). Hidden
## when empty.
var item_row: HBoxContainer
## The unit's equipped Keepsakes and Shards, to read (hover one for its effect). Shown
## whenever the match HUD's interactive item_row isn't (enemies, combat, random battles).
var _keepsake_row: HBoxContainer
var _keepsake_row_ids := []   # what the row shows, so it's only rebuilt when that changes
## The tip shown while hovering one of the selected unit's big overhead Keepsake icons.
var _hover_tip: PanelContainer
var _hover_text: RichTextLabel
var _hover_index := -1
var upgrade_row: VBoxContainer   # the match HUD's big Upgrade button, when there is one
## Stats, abilities (passives, Gambit, Ascensions), and the upgrade tree.
enum Tab { STATS, ABILITIES, UPGRADES }
const TAB_NAMES := {Tab.STATS: "Stats", Tab.ABILITIES: "Abilities", Tab.UPGRADES: "Upgrades"}
const OWNED := "#ffd24d"   # upgrades the unit has
const NOT_OWNED := "#6e6e78"

## Which tab is showing; kept from unit to unit.
var tab := Tab.STATS
var _tab_buttons: Array[Button] = []
var _shown_text := ""
## Index into TEXT_SIZES of the font size in use.
var _size_index := 0
## Font sizes tried, largest first, until the text fits.
const TEXT_SIZES := [11, 10, 9, 8, 7]
## Below this index's size, the panel first takes the space below it (the log's corner).
const USUAL_SMALLEST := 3


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP   # clicks on the panel don't reach the board
	var style := StyleBoxFlat.new()
	style.bg_color = FRAME_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	# Header: picture, name, tier and path.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(44, 44)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(_portrait)
	_title = _rich(12)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_title)

	# The match's Upgrade button (Aura upgrade system), right under the name. Filled by the HUD.
	upgrade_row = VBoxContainer.new()
	upgrade_row.visible = false
	column.add_child(upgrade_row)

	item_row = HBoxContainer.new()
	item_row.add_theme_constant_override("separation", 4)
	item_row.visible = false
	column.add_child(item_row)

	_keepsake_row = HBoxContainer.new()
	_keepsake_row.add_theme_constant_override("separation", 4)
	_keepsake_row.visible = false
	column.add_child(_keepsake_row)
	_build_hover_tip()

	# Health and charge as bars with numbers.
	var bars := _bar_row(column, "Health", HEALTH_COLOR, Keyphrases.icon_path(Shard.Kind.HEALTH))
	_health_bar = bars[0]
	_health_text = bars[1]
	bars = _bar_row(column, "Charge", CHARGE_COLOR)
	_charge_bar = bars[0]
	_charge_text = bars[1]

	# Stats / Abilities tabs.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	column.add_child(tabs)
	var group := ButtonGroup.new()
	for t in [Tab.STATS, Tab.ABILITIES, Tab.UPGRADES]:
		var button := Button.new()
		button.text = TAB_NAMES[t]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.button_pressed = t == tab
		button.pressed.connect(func(): _set_tab(t))
		tabs.add_child(button)
		_tab_buttons.append(button)
	_text = _rich(11)
	_text.mouse_filter = Control.MOUSE_FILTER_PASS   # so hovering a ward shows its tooltip (see _ward_value)
	column.add_child(_text)
	hide()


func _rich(font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	return label


## A label, a coloured bar, and the numbers on top of the bar. Returns [bar, numbers].
## A labelled bar. With `icon`, the label is that icon (the name shows on hover).
func _bar_row(parent: Container, label_text: String, color: Color, icon: String = "") -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	if icon != "":
		var picture := TextureRect.new()
		picture.texture = load(icon)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT   # at the left, lined up with "Charge" below
		picture.custom_minimum_size = Vector2(52, 16)
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		picture.tooltip_text = label_text
		row.add_child(picture)
	else:
		var label := Label.new()
		label.text = label_text
		label.custom_minimum_size = Vector2(52, 0)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(DIM))
		row.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.08)
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	row.add_child(bar)
	var numbers := Label.new()
	numbers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numbers.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	numbers.add_theme_font_size_override("font_size", 11)
	numbers.add_theme_color_override("font_outline_color", Color.BLACK)
	numbers.add_theme_constant_override("outline_size", 3)
	bar.add_child(numbers)
	return [bar, numbers]


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	# The click is in screen pixels; the units are in the world, under the camera.
	var world := get_viewport().get_canvas_transform().affine_inverse() * click.position
	# A click on the selected unit's (enlarged) Keepsake icons is for the icons (the board
	# handles it), not a click on empty ground: keep the unit selected.
	if is_instance_valid(_unit) and _unit.keepsakes_focused and _unit.keepsake_index_at(world, 1.0) >= 0:
		return
	_select(_unit_at(world))


func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_unit) or not _unit.is_inside_tree():
		_select(_replacement())   # the board was rebuilt: follow the unit to its new copy
		return
	if not _unit.alive:
		_select(null)
		return
	_refresh()
	_update_hover_tip()


## Shows `unit` in the panel and rings it, or closes the panel when it's null.
func _select(unit: BattleUnit) -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()   # off the previous unit
	_marker = null
	if is_instance_valid(_unit) and _unit != unit:
		_unit.set_keepsakes_focused(false)
	_hide_hover_tip()
	_keepsake_row_ids = [null]   # rebuild the row for the new unit
	_unit = unit
	if unit != null:
		unit.set_keepsakes_focused(true)
	visible = unit != null
	unit_selected.emit(unit)
	if unit == null:
		_army_index = -1
		return
	_shown_text = ""   # fit the new unit's text afresh
	_team = unit.team
	_army_index = unit.get_meta("army_index", -1)
	_marker = _make_marker()
	unit.add_child(_marker)
	unit.move_child(_marker, 0)   # first child, so it draws under the unit's sprite
	_refresh()


## After the board is rebuilt: the new copy of the unit that was shown, or null.
func _replacement() -> BattleUnit:
	if _army_index < 0:
		return null
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.is_inside_tree() and not unit.is_queued_for_deletion() \
				and unit.team == _team and unit.get_meta("army_index", -1) == _army_index:
			return unit
	return null


## A gold ring that gently pulses. Made a child of the selected unit, so it follows the
## unit around and disappears with it if it dies.
func _make_marker() -> Line2D:
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = MARKER_COLOR
	var points := PackedVector2Array()
	for i in 33:   # 32 segments, closing back on the first point
		points.append(Vector2.from_angle(TAU * i / 32.0) * MARKER_RADIUS)
	ring.points = points
	var pulse := ring.create_tween().set_loops()
	pulse.tween_property(ring, "scale", Vector2.ONE * 1.12, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(ring, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	return ring


## The unit whose centre is nearest `point`, if any is within PICK_RADIUS.
func _unit_at(point: Vector2) -> BattleUnit:
	var best: BattleUnit = null
	var best_dist := PICK_RADIUS
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null:
			continue
		var dist := point.distance_to(unit.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = unit
	return best


func _refresh() -> void:
	var u := _unit
	_refresh_header(u)

	var shield := u.get_shield()
	_health_bar.max_value = maxf(u.max_health, 1.0)
	_health_bar.value = u.health
	_health_text.text = "%d / %d" % [roundi(u.health), roundi(u.max_health)]
	if shield > 0.0:
		_health_text.text += "  +%d shield" % roundi(shield)
	_charge_bar.get_parent().visible = u.gambit != null
	if u.gambit != null:
		_charge_bar.max_value = maxf(u.max_charge, 1.0)
		_charge_bar.value = u.charge
		_charge_text.text = "%d / %d" % [roundi(u.charge), roundi(u.max_charge)]

	_refresh_keepsake_row(u)
	var text := _stat_table(u)
	if tab == Tab.ABILITIES:
		text = _abilities_text(u)
	elif tab == Tab.UPGRADES:
		text = _upgrades_text(u)
	if text != _shown_text:
		if _shown_text == "":   # a new unit or tab: start large again; _fit steps it down
			_set_text_size(0)
		_shown_text = text
		_text.text = text
	_fit()


## The read-only Keepsakes row: an icon per equipped item, each with its effect on hover.
## Hidden while the HUD's own item row (planning, your unit) is showing, or with nothing on.
func _refresh_keepsake_row(u: BattleUnit) -> void:
	var show_row := not item_row.visible and not u.keepsakes.is_empty()
	var ids := u.keepsakes.map(func(k): return k.get_instance_id()) if show_row else []
	if ids == _keepsake_row_ids and _keepsake_row.visible == show_row:
		return
	_keepsake_row_ids = ids
	for child in _keepsake_row.get_children():
		child.queue_free()
	_keepsake_row.visible = show_row
	if not show_row:
		return
	var title := Label.new()
	title.text = "Keepsakes"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(DIM))
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_keepsake_row.add_child(title)
	for keepsake in u.keepsakes:
		var icon := RichTooltipRect.new()
		icon.texture = keepsake.get_icon()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(22, 22)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.tooltip_text = ItemToolbox.describe(keepsake)
		_keepsake_row.add_child(icon)


func _build_hover_tip() -> void:
	_hover_tip = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = FRAME_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	_hover_tip.add_theme_stylebox_override("panel", style)
	_hover_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_tip.top_level = true   # placed by the mouse, not inside the panel
	_hover_tip.z_index = 100
	_hover_text = RichTextLabel.new()
	_hover_text.bbcode_enabled = true
	_hover_text.fit_content = true
	_hover_text.scroll_active = false
	_hover_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hover_text.custom_minimum_size = Vector2(230, 0)
	_hover_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_text.add_theme_font_size_override("normal_font_size", 11)
	Keyphrases.style_label(_hover_text, 11)
	_hover_text.add_theme_font_size_override("bold_font_size", 11)
	_hover_tip.add_child(_hover_text)
	_hover_tip.hide()
	add_child(_hover_tip)


## While the mouse is over one of the selected unit's big overhead Keepsake icons, shows that
## Keepsake's effect beside the mouse. Read from the mouse position each frame rather than
## from the icons themselves, so the board still gets every click (dragging a Shard off).
func _update_hover_tip() -> void:
	var index := -1
	if is_instance_valid(_unit) and _unit.keepsakes_focused:
		index = _unit.keepsake_index_at(_unit.get_global_mouse_position(), 1.0)
	if index < 0 or index >= _unit.keepsakes.size():
		_hide_hover_tip()
		return
	if index != _hover_index:
		_hover_index = index
		_hover_text.text = ItemToolbox.describe_rich(_unit.keepsakes[index], "", _unit)
		_hover_tip.size = Vector2.ZERO   # shrink to the new text
	_hover_tip.show()
	var mouse := get_global_mouse_position()
	var screen := get_viewport_rect().size / get_canvas_transform().get_scale()
	var at := mouse + Vector2(14, 14)
	at.x = minf(at.x, screen.x - _hover_tip.size.x - 4.0)
	at.y = minf(at.y, screen.y - _hover_tip.size.y - 4.0)
	_hover_tip.global_position = at


func _hide_hover_tip() -> void:
	_hover_index = -1
	if _hover_tip != null:
		_hover_tip.hide()


## Fits the panel again from the largest font, after top_reserve or bottom_reserve change.
func relayout() -> void:
	if is_instance_valid(_unit) and visible:
		_shown_text = ""
		_refresh()


func _set_tab(t: Tab) -> void:
	tab = t
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == t)
	_shown_text = ""
	if is_instance_valid(_unit):
		_refresh()


func _set_text_size(index: int) -> void:
	_size_index = index
	_text.add_theme_font_size_override("normal_font_size", TEXT_SIZES[index])
	Keyphrases.style_label(_text, TEXT_SIZES[index])
	_text.add_theme_font_size_override("bold_font_size", TEXT_SIZES[index])


## Keeps the panel between top_reserve and bottom_reserve, centred in that space. Text only
## gets its real height once laid out, so this runs every frame: while the panel is still
## too tall it steps the font down one size.
func _fit() -> void:
	var room := get_viewport_rect().size.y - top_reserve - bottom_reserve
	var full := get_viewport_rect().size.y - top_reserve - 8.0   # the space below (the log's corner) too
	var height := get_combined_minimum_size().y
	if height > room and _size_index < USUAL_SMALLEST:
		_set_text_size(_size_index + 1)
	elif height > full and _size_index < TEXT_SIZES.size() - 1:
		_set_text_size(_size_index + 1)   # only once it's taken the space below and still doesn't fit
	if height > room:
		room = full
	reset_size()
	anchor_top = 0.0
	anchor_bottom = 0.0
	position.y = top_reserve + maxf((room - size.y) / 2.0, 0.0)


func _abilities_text(u: BattleUnit) -> String:
	var lines: PackedStringArray = []
	for passive in u.passives:
		lines.append(_ability_line("Passive", _ability_name(passive, passive.passive_name, "Passive"), passive.description,
				DescriptionContext.of(passive).with_unit(u)))
	if u.gambit != null:   # the unit's own Gambit: its upgrades' bonuses are already in it
		lines.append(_ability_line("Gambit", _ability_name(u.gambit, u.gambit.gambit_name, "Gambit"), u.gambit.description,
				DescriptionContext.of(u.gambit).with_unit(u, true)))
	for ascension in u.ascensions:
		if ascension.is_chosen():
			lines.append(_ability_line("Ascension", ascension.get_display_name(), ascension.description,
					ascension.description_context().with_unit(u)))
	return "\n".join(lines).strip_edges()


## The unit's whole upgrade tree, each upgrade with its label (A, A1...), name and what it
## does: the ones it has in gold with a tick, the rest greyed out.
func _upgrades_text(u: BattleUnit) -> String:
	if u.data == null or u.data.upgrades.is_empty():
		return "[color=%s]No upgrades.[/color]" % DIM
	var owned := u.get_chosen_upgrades()
	var lines: PackedStringArray = []
	for first in u.data.upgrades.size():
		var upgrade := u.data.upgrades[first]
		lines.append(_upgrade_line(u, [first], upgrade, owned.has(upgrade), 0))
		for second in upgrade.next_choices.size():
			var final := upgrade.next_choices[second]
			lines.append(_upgrade_line(u, [first, second], final, owned.has(final), 1))
		lines.append("")
	return "\n".join(lines).strip_edges()


func _upgrade_line(u: BattleUnit, path: Array, upgrade: Upgrade, has: bool, depth: int) -> String:
	var data := u.data
	var color := OWNED if has else NOT_OWNED
	var title := upgrade.upgrade_name if upgrade.upgrade_name != "Upgrade" else ""
	var head := "[indent]" if depth > 0 else ""
	var tail := "[/indent]" if depth > 0 else ""
	var line := "%s[color=%s][b]%s%s[/b]%s[/color]" % [head, color, "✓ " if has else "", RandomTeams.path_label(path),
			("  " + title) if title != "" else ""]
	if upgrade.description != "":
		# Its numbers: the totals once taken, from the unit's stats (as if at that level).
		var ctx := DescriptionContext.for_upgrade(data, path)
		if has:
			ctx.with_unit(u, Upgrade.touches_gambit(upgrade))
		else:
			ctx.with_unit_at_level(u, path.size(), Upgrade.touches_gambit(upgrade))
		var text := Keyphrases.format(upgrade.description, ctx) if has else Keyphrases.plain(upgrade.description, ctx)
		line += "\n[color=%s]%s[/color]" % [DESCRIPTION if has else NOT_OWNED, text]
	return line + tail


func _refresh_header(u: BattleUnit) -> void:
	_portrait.texture = u.data.sprite if u.data != null else null
	var title := u.data.get_title() if u.data != null else str(u.name)
	var adjective := UnitData.path_adjective(u.get_chosen_upgrades()) if u.data != null else ""
	if adjective != "":   # "Mystical Bremes": the upgrade path's word, in the upgrade button's cyan
		title = "[i][color=%s]%s[/color][/i] %s" % [MatchHud.UPGRADE_CYAN.to_html(false), adjective, title]
	var line := "[font_size=17][b]%s[/b][/font_size]" % title
	if u.is_summon:
		line += "  [color=%s](summon)[/color]" % DIM
	var details: PackedStringArray = []
	if u.data != null:
		details.append("Tier %d" % u.data.tier)
	var upgrades := u.get_chosen_upgrades()
	if upgrades.is_empty():
		details.append("no upgrades")
	else:
		var label := RandomTeams.path_label(u.upgrade_path)
		if upgrades.size() > u.upgrade_path.size():   # Convergence: both final upgrades
			var other: Array[int] = u.upgrade_path.duplicate()
			other[-1] = 1 - other[-1]
			var pair := [label, RandomTeams.path_label(other)]
			pair.sort()   # "A1 + A2" whichever was bought
			label = "%s + %s" % pair
		details.append(label)   # the names and what they do are on the Upgrades tab
	if u.buffs > 0:
		details.append("%d buff%s" % [u.buffs, "" if u.buffs == 1 else "s"])
	line += "\n[color=%s]%s[/color]" % [DIM, "  ·  ".join(details)]
	_title.text = line


## A grid: each attribute's row shows its value and its ward, in the Shards' colours, under
## "Value" and "Ward" headings; wrack's row shows chance and damage under its own headings.
## Then vampirism, range, attack speed, regen and dodge, two to a row, in plain colours.
## A stat that something is changing shows how far from its base it is, green for up,
## red for down.
func _stat_table(u: BattleUnit) -> String:
	var grid := _heading_row("Value", "Ward")
	for row in STAT_ROWS:
		var attribute: Stats.Stat = row[0]
		var ward: Stats.Stat = row[1]
		if attribute == Stats.Stat.WRACK_CHANCE:
			grid += _heading_row("Chance", "Damage")
			grid += _icon_cell(Shard.Kind.WRACK, "Wrack")
		else:
			grid += _icon_cell(STAT_SHARDS[attribute], Stats.STAT_NAMES[attribute])
		grid += "[cell padding=0,1,12,1]%s[/cell]" % _stat_value(u, attribute)
		grid += "[cell padding=0,1,0,1][color=%s]%s[/color][/cell]" % [
				_stat_color(ward).to_html(false), _ward_value(u, ward)]
	var out := "[table=3]%s[/table]" % grid

	var cells: PackedStringArray = []
	var extra: Array = []   # [name, value] pairs, two to a row
	if _shown_stat(u, Stats.Stat.VAMPIRISM) > 0.0:
		extra.append([Stats.STAT_NAMES[Stats.Stat.VAMPIRISM], _stat_value(u, Stats.Stat.VAMPIRISM)])
	if _shown_stat(u, Stats.Stat.IMMOVABILITY) > 0.0:
		extra.append([Stats.STAT_NAMES[Stats.Stat.IMMOVABILITY], _stat_value(u, Stats.Stat.IMMOVABILITY)])
	if _shown_stat(u, Stats.Stat.GRIT) > 0.0:
		extra.append([Stats.STAT_NAMES[Stats.Stat.GRIT], _stat_value(u, Stats.Stat.GRIT)])
	if _shown_stat(u, Stats.Stat.SCAR) > 0.0:
		extra.append([Stats.STAT_NAMES[Stats.Stat.SCAR], "%d%%" % roundi(_shown_stat(u, Stats.Stat.SCAR))])
	extra.append(["Damage", _attack_type_text(u)])
	extra.append(["Range", "[b]%d[/b]" % u.attack_range])
	extra.append(["Attack every", "[b]%.2fs[/b]" % u.get_attack_cooldown()])
	extra.append(["Regen", "[b]%.1f/s[/b]" % u.get_health_regen()])
	if Stats.insight_charge_regen and u.gambit != null:
		extra.append(["Charge Regen", "[b]%.1f/s[/b]" % u.get_charge_regen()])
	var dodge := u.get_dodge_chance()
	if not u.active:   # Ascensions' dodge only starts working when combat does
		for ascension in u.ascensions:
			if ascension.applies_to(u.data):
				dodge += ascension.dodge_chance
	if dodge > 0.0:
		extra.append(["Dodge", "[b]%d%%[/b]" % roundi(dodge * 100.0)])
	if extra.size() % 2 == 1:
		extra.append(["", ""])
	for pair in extra:
		cells.append(_cells(Color(DIM), pair[0], pair[1]))
	return out + "\n[table=4]%s[/table]" % "".join(cells)


## The kind of damage the unit's attacks deal (after anything changing it), in that damage
## type's colour; "None" for a unit that never attacks (Gateway).
func _attack_type_text(u: BattleUnit) -> String:
	if u.data != null and u.data.passives.any(func(p): return p is GatePassive):
		return "[b]None[/b]"
	var damage_type := u.get_attack_damage_type()
	var kinds := {Stats.DamageType.MIGHT: Shard.Kind.MIGHT, Stats.DamageType.INSIGHT: Shard.Kind.INSIGHT,
			Stats.DamageType.CELERITY: Shard.Kind.CELERITY}
	if kinds.has(damage_type):   # Might, Insight or Celerity: its icon
		return stat_icon(kinds[damage_type], Stats.DAMAGE_TYPE_NAMES[damage_type])
	return "[b][color=%s]%s[/color][/b]" % [Stats.DAMAGE_TYPE_COLORS[damage_type].to_html(false), Stats.DAMAGE_TYPE_NAMES[damage_type]]


func _heading_row(first: String, second: String) -> String:
	return "[cell][/cell][cell padding=0,3,12,0][color=%s][font_size=10]%s[/font_size][/color][/cell][cell padding=0,3,0,0][color=%s][font_size=10]%s[/font_size][/color][/cell]" % [
			DIM, first.to_upper(), DIM, second.to_upper()]


## A stat's icon in place of its name (the name shows on hover).
const ICON_SIZE := 14


static func stat_icon(kind: Shard.Kind, stat_name: String, size: int = ICON_SIZE) -> String:
	return "[hint=%s][img=%dx%d]%s[/img][/hint]" % [stat_name, size, size, Keyphrases.icon_path(kind)]


func _icon_cell(kind: Shard.Kind, stat_name: String) -> String:
	return "[cell padding=0,1,12,1]%s[/cell]" % stat_icon(kind, stat_name)


func _grid_cell(color: Color, label: String) -> String:
	return "[cell padding=0,1,12,1][color=%s]%s[/color][/cell]" % [color.to_html(false), label]


func _cells(color: Color, label: String, value: String) -> String:
	return "[cell padding=0,1,5,1][color=%s]%s[/color][/cell][cell padding=0,1,12,1]%s[/cell]" % [
			color.to_html(false), label.replace(" ", char(160)), value]   # names never wrap


## A ward's value, with a tooltip saying how much of its damage type it blocks.
const WARD_TYPES := {
	Stats.Stat.MIGHT_WARD: Stats.DamageType.MIGHT,
	Stats.Stat.INSIGHT_WARD: Stats.DamageType.INSIGHT,
	Stats.Stat.CELERITY_WARD: Stats.DamageType.CELERITY,
}

func _ward_value(u: BattleUnit, ward: Stats.Stat) -> String:
	if not WARD_TYPES.has(ward):
		return _stat_value(u, ward)   # the wrack row's second column isn't a ward
	var blocked := 1.0 - Stats.ward_multiplier(_shown_stat(u, ward))
	var hint := "Blocks %d%% of %s damage" % [roundi(blocked * 100.0), Stats.DAMAGE_TYPE_NAMES[WARD_TYPES[ward]]]
	return "[hint=\"%s\"]%s[/hint]" % [hint, _stat_value(u, ward)]


## The stat's value in bold, and how far it is from base if something is changing it.
func _stat_value(u: BattleUnit, stat: Stats.Stat) -> String:
	var now := _shown_stat(u, stat)
	var base: float = u.base_stats.get(stat, 0.0)
	var value := "[b]%s[/b]" % _format(stat, now)
	if not is_equal_approx(now, base):
		var up := now > base
		value += " [color=%s][font_size=10]%s%s[/font_size][/color]" % [UP if up else DOWN,
				"+" if up else "−", _format(stat, absf(now - base), true)]
	return value


## A stat as the unit will have it. Items only start working when combat does, so outside
## combat (planning) their bonuses are added here.
func _shown_stat(u: BattleUnit, stat: Stats.Stat) -> float:
	var value := u.get_stat(stat)
	if not u.active and not u.previewing:   # not previewed: items and Ascensions only start working when combat does
		for keepsake in u.keepsakes:
			value += keepsake.get_stat_bonuses().get(stat, 0.0)
		for ascension in u.ascensions:
			if ascension.applies_to(u.data):
				value += ascension.get_stat_bonuses().get(stat, 0.0)
	return maxf(value, 0.0)


## A stat's Shard colour, brightened so it reads on the dark panel; white if no Shard gives it.
static func _stat_color(stat: Stats.Stat) -> Color:
	if not STAT_SHARDS.has(stat):
		return Color(0.85, 0.85, 0.9)
	return Keyphrases.color_of(STAT_SHARDS[stat])


## Wrack chance and vampirism as percentages, wrack damage as "+N%", everything else as a
## whole number. `bare` leaves the "+" off wrack damage, for showing a difference.
static func _format(stat: Stats.Stat, value: float, bare: bool = false) -> String:
	match stat:
		Stats.Stat.WRACK_DAMAGE:
			return ("%d%%" if bare else "+%d%%") % roundi(value * 100.0)
		Stats.Stat.WRACK_CHANCE, Stats.Stat.VAMPIRISM:
			return "%d%%" % roundi(value * 100.0)
	return str(roundi(value))


static func _ability_line(kind: String, ability_name: String, description: String, ctx: DescriptionContext = null) -> String:
	var line := "[color=%s]%s[/color]  [b]%s[/b]" % [DIM, kind.to_upper(), ability_name]
	if description != "":
		line += "\n[color=%s]%s[/color]" % [DESCRIPTION, Keyphrases.format(description, ctx)]
	return line + "\n"


## The ability's set name, or one made from its class when the name was left at the
## default: StarburnPassive -> "Starburn".
static func _ability_name(resource: Resource, given_name: String, default_name: String) -> String:
	if given_name != "" and given_name != default_name:
		return given_name
	var script := resource.get_script() as Script
	if script == null or script.get_global_name() == "":
		return default_name
	return String(script.get_global_name()).trim_suffix(default_name).capitalize()


## The unit currently shown, or null.
func get_unit() -> BattleUnit:
	return _unit if is_instance_valid(_unit) else null
