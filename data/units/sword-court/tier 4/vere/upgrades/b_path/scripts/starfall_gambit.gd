class_name StarfallGambit
extends Gambit
## Leaps into the air, untargetable, and rains a quick series of attacks down on enemies
## inside a circle, then lands inside it. Each strike is a real attack, on a random enemy
## in the circle (or, with Target Lowest Health, the weakest one).

const CIRCLE_COLOR := Color(0.65, 0.75, 1.0, 0.7)   # starlight

## How far from her the circle's center can be, in hex cells.
@export var cast_range_cells: int = 5
## The circle's size in hex cells. 2 = the center plus two rings around it.
@export var radius_cells: int = 2
@export var strikes: int = 6
## Seconds between strikes.
@export var strike_interval: float = 0.2
## Every strike goes at the enemy in the circle with the least health.
@export var target_lowest_health: bool = false
## Extra strikes each time an enemy that was in the circle dies during the rain. 0 = none.
@export var strikes_per_kill: int = 0
@export var max_extra_strikes: int = 6


## Only casts if some circle would have an enemy in it.
func can_use(caster: BattleUnit) -> bool:
	return _best_center(caster)["count"] > 0


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var spot := _best_center(caster)
	if spot["count"] == 0:
		return
	var center: Vector2i = spot["cell"]
	var circle := _draw_circle(caster, center)
	var airborne := UntargetableStatus.new(INF)   # removed by hand when she lands
	caster.add_status(airborne)

	var seen := {}      # instance id -> enemy, for every enemy that stood in the circle
	var counted := {}   # ids whose deaths already earned extra strikes
	var extra := 0
	var done := 0
	while done < strikes + extra:
		# She may have died, or the battle ended, between strikes.
		if not _alive(caster) or not caster.active:
			break
		var inside := _enemies_in_circle(caster, center)
		if inside.is_empty():
			break   # nobody left to hit
		for enemy in inside:
			seen[enemy.get_instance_id()] = enemy
		caster.lock_for((strikes + extra - done) * strike_interval)
		caster.attack_now(_lowest(inside) if target_lowest_health else CombatRng.pick(inside))
		done += 1
		await caster.get_tree().create_timer(strike_interval, true, true).timeout
		if strikes_per_kill > 0:
			for id in seen:
				if not counted.has(id) and not _alive(seen[id]):
					counted[id] = true
					extra = mini(extra + strikes_per_kill, max_extra_strikes)

	if _alive(caster):
		caster.remove_status(airborne)
		var landing := _landing_cell(caster, center)
		if landing != caster.cell:
			caster.place_at(landing)
	_fade(circle)


## The enemy cell, within cast range, that has the most enemies within the circle's
## radius. Ties go to the nearest. Returns {"cell": Vector2i, "count": enemies inside}.
func _best_center(caster: BattleUnit) -> Dictionary:
	var grid := caster.grid
	var enemies := _living_enemies(caster)
	var best := {"cell": caster.cell, "count": 0}
	var best_dist := INF
	for candidate in enemies:
		var dist := grid.get_distance(caster.cell, candidate.cell)
		if dist > cast_range_cells:
			continue
		var count := enemies.filter(func(e): return grid.get_distance(candidate.cell, e.cell) <= radius_cells).size()
		if count > best["count"] or (count == best["count"] and dist < best_dist):
			best = {"cell": candidate.cell, "count": count}
			best_dist = dist
	return best


func _enemies_in_circle(caster: BattleUnit, center: Vector2i) -> Array[BattleUnit]:
	return _living_enemies(caster).filter(
			func(e): return caster.grid.get_distance(center, e.cell) <= radius_cells)


func _living_enemies(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team:
			result.append(unit)
	return result


func _lowest(units: Array[BattleUnit]) -> BattleUnit:
	var best: BattleUnit = units[0]
	for unit in units:
		if unit.health < best.health:
			best = unit
	return best


## The free cell in the circle closest to its center, or her own cell if it's full.
func _landing_cell(caster: BattleUnit, center: Vector2i) -> Vector2i:
	var grid := caster.grid
	var cells := grid.free_cells_in_range(center, radius_cells)
	if cells.is_empty():
		return caster.cell
	cells.sort_custom(func(a, b): return grid.get_distance(center, a) < grid.get_distance(center, b))
	return cells[0]


## A starlit ring on the ground marking the circle.
func _draw_circle(caster: BattleUnit, center: Vector2i) -> Line2D:
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = CIRCLE_COLOR
	ring.z_index = -1   # on the ground, under the units
	var r := (radius_cells + 0.5) * caster.grid.cell_spacing()
	var points := PackedVector2Array()
	for i in 33:   # 32 segments, closing back on the first point
		points.append(Vector2.from_angle(TAU * i / 32.0) * r)
	ring.points = points
	caster.get_tree().current_scene.add_child(ring)
	ring.global_position = caster.grid.cell_to_world(center)
	return ring


func _fade(ring) -> void:   # untyped: the ring may already be gone if the battle was cleared
	if not is_instance_valid(ring):
		return
	var tween: Tween = ring.create_tween()
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.tween_callback(ring.queue_free)


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive
