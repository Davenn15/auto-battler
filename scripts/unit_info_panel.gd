class_name UnitInfoPanel
extends PanelContainer
## Click a unit to show its name, upgrades, abilities, and live stats. Click empty ground
## to close. Refreshes every frame while open, so buffs and damage show as they happen.

const PICK_RADIUS := 30.0   # how close to a unit's centre a click must be, in pixels
const MARKER_COLOR := Color(1.0, 0.85, 0.3, 0.9)   # gold ring under the selected unit
const MARKER_RADIUS := 26.0

## Sent whenever the selected unit changes (null when the panel closes). The item toolbox
## uses it to know which unit to equip.
signal unit_selected(unit: BattleUnit)

var _unit: BattleUnit = null
var _text: RichTextLabel
var _marker: Line2D   # the ring under the selected unit; a child of that unit


func _ready() -> void:
	custom_minimum_size = Vector2(290, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP   # clicks on the panel don't reach the board
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(270, 0)
	_text.add_theme_font_size_override("normal_font_size", 12)
	_text.add_theme_font_size_override("bold_font_size", 12)
	add_child(_text)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	# The click is in screen pixels; the units are in the world, under the camera.
	var world := get_viewport().get_canvas_transform().affine_inverse() * click.position
	_select(_unit_at(world))


func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_unit) or not _unit.alive:
		_select(null)
		return
	_refresh()


## Shows `unit` in the panel and rings it, or closes the panel when it's null.
func _select(unit: BattleUnit) -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()   # off the previous unit
	_marker = null
	_unit = unit
	visible = unit != null
	unit_selected.emit(unit)
	if unit == null:
		return
	_marker = _make_marker()
	unit.add_child(_marker)
	unit.move_child(_marker, 0)   # first child, so it draws under the unit's sprite
	_refresh()


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
	var lines: PackedStringArray = []
	var title := u.data.display_name.capitalize() if u.data != null else str(u.name)
	if u.is_summon:
		title += " (summon)"
	lines.append("[font_size=16][b]%s[/b][/font_size]" % title)
	if u.data != null:
		lines.append("Tier %d   ·   Team %d" % [u.data.tier, u.team])

	# Upgrades taken, in order.
	var upgrades := u.get_chosen_upgrades()
	if upgrades.is_empty():
		lines.append("Level 0 (no upgrades)")
	else:
		var names: PackedStringArray = []
		for upgrade in upgrades:
			names.append(upgrade.upgrade_name)
		lines.append("Level %d: %s" % [upgrades.size(), " → ".join(names)])

	# Health, shield, charge.
	lines.append("")
	var shield := u.get_shield()
	var health_line := "[b]Health[/b] %d / %d" % [roundi(u.health), roundi(u.max_health)]
	if shield > 0.0:
		health_line += "   [color=#bbbbbb]+%d shield[/color]" % roundi(shield)
	lines.append(health_line)
	if u.gambit != null:
		lines.append("[b]Charge[/b] %d / %d" % [roundi(u.charge), roundi(u.max_charge)])

	# Abilities.
	lines.append("")
	for passive in u.passives:
		lines.append(_ability_line("Passive", _ability_name(passive, passive.passive_name, "Passive"), passive.description))
	if u.gambit != null:
		lines.append(_ability_line("Gambit", _ability_name(u.gambit, u.gambit.gambit_name, "Gambit"), u.gambit.description))
	for upgrade in upgrades:
		if upgrade.description != "":
			lines.append(_ability_line("Upgrade", upgrade.upgrade_name, upgrade.description))

	# Stats: the current value, with the base value when something is changing it.
	lines.append("")
	lines.append("[b]Stats[/b]")
	for stat in Stats.Stat.values():
		var now := u.get_stat(stat)
		var base: float = u.base_stats.get(stat, 0.0)
		lines.append("%s: %s%s" % [Stats.STAT_NAMES[stat], _format(stat, now),
				"" if is_equal_approx(now, base) else "  [color=#888888](base %s)[/color]" % _format(stat, base)])
	lines.append("Attack range: %d" % u.attack_range)
	lines.append("Attack every: %.2fs" % u.get_attack_cooldown())
	lines.append("Health regen: %.1f/s" % u.get_health_regen())
	var dodge := u.get_dodge_chance()
	if dodge > 0.0:
		lines.append("Dodge chance: %d%%" % roundi(dodge * 100.0))
	_text.text = "\n".join(lines)


## Wrack chance as a percentage, wrack damage as "+N%", everything else as a whole number.
static func _format(stat: Stats.Stat, value: float) -> String:
	match stat:
		Stats.Stat.WRACK_CHANCE:
			return "%d%%" % roundi(value * 100.0)
		Stats.Stat.WRACK_DAMAGE:
			return "+%d%%" % roundi(value * 100.0)
		Stats.Stat.WRACK_CHANCE, Stats.Stat.VAMPIRISM:
			return "%d%%" % roundi(value * 100.0)
	return str(roundi(value))


static func _ability_line(kind: String, ability_name: String, description: String) -> String:
	var line := "[b]%s: %s[/b]" % [kind, ability_name]
	if description != "":
		line += "\n[color=#cccccc]%s[/color]" % description
	return line


## The ability's set name, or one made from its class when the name was left at the
## default: StarburnPassive -> "Starburn".
static func _ability_name(resource: Resource, set_name: String, default_name: String) -> String:
	if set_name != "" and set_name != default_name:
		return set_name
	var script := resource.get_script() as Script
	if script == null or script.get_global_name() == "":
		return default_name
	return String(script.get_global_name()).trim_suffix(default_name).capitalize()


## The unit currently shown, or null.
func get_unit() -> BattleUnit:
	return _unit if is_instance_valid(_unit) else null
