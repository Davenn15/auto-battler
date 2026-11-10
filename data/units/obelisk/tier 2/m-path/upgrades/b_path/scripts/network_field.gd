class_name NetworkField
extends Node2D
## M-PATH's Networked field (see NetworkGambit): a rectangle that, while it lasts, keeps
## evening out the health of every ally inside it. Health moves from the healthiest to the
## most hurt (by share of max health), so the total stays the same. B1 and B2 give allies
## inside more wards and health regen.

const COLOR := PathLink.COLOR

var source   # M-PATH; untyped because he may be freed
var team: int
var credit_id: int
var rect: Rect2   # in world space
var time_left: float
## Share of the gap to the even level closed each second (1.0 = all of it in a second).
var rate: float
var ward_bonus: float
var regen_bonus: float
var _bonus := {}   # instance id -> FieldStatus on allies inside, for B1/B2
var _time := 0.0
var _inside: Array[BattleUnit] = []


func _physics_process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		end()
		return
	_inside = _allies_inside()
	_update_bonuses()
	if _inside.size() < 2:
		return
	var total := 0.0
	var total_max := 0.0
	for unit in _inside:
		total += unit.health
		total_max += unit.max_health
	var level := total / total_max   # the share of max health everyone would have if even
	var step := minf(rate * delta, 1.0)
	for unit in _inside:
		var change := (unit.max_health * level - unit.health) * step
		unit.set_health(unit.health + change)
		if change > 0.0:
			get_tree().call_group("damage_tracker", "record_healing", credit_id, change)


func _allies_inside() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.active and unit.team == team and rect.has_point(unit.global_position):
			result.append(unit)
	return result


func _update_bonuses() -> void:
	if ward_bonus <= 0.0 and regen_bonus <= 0.0:
		return
	var ids := {}
	for unit in _inside:
		ids[unit.get_instance_id()] = true
		if not _bonus.has(unit.get_instance_id()):
			var status := FieldStatus.new(ward_bonus, regen_bonus)
			_bonus[unit.get_instance_id()] = status
			unit.add_status(status)
	for id in _bonus.keys():
		if not ids.has(id):
			_remove_bonus(id)


func _remove_bonus(id: int) -> void:
	var unit := instance_from_id(id) as BattleUnit
	if unit != null:
		unit.remove_status(_bonus[id])
	_bonus.erase(id)


func end() -> void:
	for id in _bonus.keys():
		_remove_bonus(id)
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var local := Rect2(to_local(rect.position), rect.size)
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	var fade := clampf(time_left / 0.3, 0.0, 1.0)
	draw_rect(local, Color(COLOR, (0.08 + 0.04 * pulse) * fade), true)
	draw_rect(local, Color(COLOR, 0.8 * fade), false, 2.0)
	# A faint grid, so it reads as a field.
	for i in range(1, 4):
		var x := local.position.x + local.size.x * i / 4.0
		draw_line(Vector2(x, local.position.y), Vector2(x, local.end.y), Color(COLOR, 0.15 * fade), 1.0)
	# Threads joining every ally inside to the middle.
	var middle := local.get_center()
	for unit in _inside:
		if is_instance_valid(unit) and unit.alive:
			var at := to_local(unit.global_position)
			draw_line(middle, at, Color(COLOR, 0.6 * fade), 1.5, true)
			draw_circle(middle.lerp(at, fmod(_time * 1.2, 1.0)), 2.5, Color(1, 1, 1, 0.8 * fade))
	draw_circle(middle, 4.0, Color(COLOR, 0.9 * fade))


## On allies inside the field with B1 or B2: more wards and health regen.
class FieldStatus extends Status:
	var wards: float
	var regen: float

	func _init(p_wards: float, p_regen: float) -> void:
		wards = p_wards
		regen = p_regen

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat in [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]:
			return value + wards
		return value

	func modify_health_regen(_unit: BattleUnit, value: float) -> float:
		return value + regen
