class_name RampingBurnStatus
extends Status
## Starlight burning on a unit: deals `total` damage over `duration` seconds, slowly at
## first and faster toward the end. Each hit adds its own, so they stack. The hit it came
## from already went through wards, so the burn skips them.
## Looks: a pale blue star around the unit that brightens as its burns ramp up, and pops
## each time one finishes (see StarburnStar).

var source_id: int   # who the damage meter credits
var total: float
var duration: float
var _elapsed: float = 0.0


func _init(p_source_id: int, p_total: float, p_duration: float) -> void:
	source_id = p_source_id
	total = p_total
	duration = maxf(p_duration, 0.01)


## How far through the burn is: 0 at the start, 1 when it's done.
func progress() -> float:
	return _elapsed / duration


func on_applied(unit: BattleUnit) -> void:
	if KeepsakeVfx.enabled() and unit.get_node_or_null(StarburnStar.KEY) == null:
		var star := StarburnStar.new()
		star.name = StarburnStar.KEY
		star.z_index = 11
		unit.add_child(star)


func tick(unit: BattleUnit, delta: float) -> void:
	if not unit.active:
		return
	var before := _elapsed
	_elapsed = minf(_elapsed + delta, duration)
	# Damage dealt so far grows with the square of the time passed, so the rate keeps
	# climbing: a quarter of the total lands in the first half, three quarters in the second.
	var amount := total * (_elapsed * _elapsed - before * before) / (duration * duration)
	var dealt := unit.take_warded_damage(amount)
	unit.add_running_damage("starburn", dealt, StarburnStar.COLOR)
	unit.get_tree().call_group("damage_tracker", "record_damage", source_id, dealt)
	if _elapsed >= duration:
		unit.remove_status(self)
		var star := unit.get_node_or_null(StarburnStar.KEY) as StarburnStar
		if star != null:
			star.pop()


## A pale blue four-pointed star around a burning unit. One per unit, however many burns
## it has: it shines as bright as the furthest-along burn, pops when a burn finishes, and
## goes away once none are left.
class StarburnStar extends Node2D:
	const KEY := "StarburnStar"
	const COLOR := Color(0.7, 0.85, 1.0)
	var _shine := 0.0
	var _pop := 0.0      # counts down after a pop: a quick flash and swell
	var _spin := 0.0

	func pop() -> void:
		_pop = 0.25
		KeepsakeVfx.burst(get_parent() as BattleUnit, COLOR)

	func _process(delta: float) -> void:
		var unit := get_parent() as BattleUnit
		var best := -1.0
		if unit != null and unit.alive:
			for status in unit.statuses:
				if status is RampingBurnStatus:
					best = maxf(best, status.progress())
		_pop = maxf(_pop - delta, 0.0)
		if best < 0.0 and _pop <= 0.0:
			queue_free()
			return
		_shine = maxf(best, 0.0)
		_spin += delta * (0.6 + _shine * 2.0)
		queue_redraw()

	func _draw() -> void:
		var unit := get_parent() as BattleUnit
		var size := KeepsakeVfx._sprite_size(unit).x * 0.55 if unit != null else 26.0
		var swell := 1.0 + 0.5 * (_pop / 0.25)
		var r := size * (0.75 + 0.25 * _shine) * swell
		var alpha := 0.4 + 0.6 * _shine
		if _pop > 0.0:
			alpha = maxf(alpha, _pop / 0.25)
		var points := PackedVector2Array()
		for i in 8:   # four long points and four short dips between them
			var reach := r if i % 2 == 0 else r * 0.28
			points.append(Vector2.from_angle(_spin + TAU * i / 8.0) * reach + Vector2(0, -8))
		draw_colored_polygon(points, Color(COLOR, alpha * 0.35))
		points.append(points[0])
		draw_polyline(points, Color(COLOR.lightened(0.4 * _shine), alpha), 2.0, true)
		draw_circle(Vector2(0, -8), 3.0 + 4.0 * _shine, Color(1, 1, 1, alpha * 0.7))
