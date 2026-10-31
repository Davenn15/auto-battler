class_name DashStrikeGambit
extends Gambit
## Dashes next to the enemy furthest from the caster, then attacks it several times in
## quick succession. The strikes are real attacks: they use the caster's normal damage,
## can wrack, and trigger on-attack effects.

const NO_CELL := Vector2i(-9999, -9999)

@export var strikes: int = 2
## Seconds the dash takes.
@export var dash_time: float = 0.15
## Seconds between strikes.
@export var strike_interval: float = 0.15
## Appear at the target instantly instead of sliding there.
@export var teleport: bool = false
## Seconds enemies can't target the caster, starting as it moves. 0 = none.
@export var untargetable_time: float = 0.0


## Only fires if there's an enemy it can reach, so charge isn't wasted.
func can_use(caster: BattleUnit) -> bool:
	return not _find_target(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var found := _find_target(caster)
	if found.is_empty():
		return
	var target: BattleUnit = found["target"]
	var dest: Vector2i = found["cell"]

	var move_time := 0.0 if teleport else dash_time
	# Keeps the unit from moving or attacking on its own until the sequence is done.
	caster.lock_for(move_time + strikes * strike_interval)
	caster.target = target
	if untargetable_time > 0.0:
		caster.add_status(UntargetableStatus.new(untargetable_time))

	if dest != caster.cell:
		if teleport:
			caster.place_at(dest)
		else:
			var start := caster.global_position
			caster.place_at(dest)   # the logical move is instant; the slide below is only visual
			var end := caster.global_position
			caster.global_position = start
			caster.create_tween().tween_property(caster, "global_position", end, dash_time)
			await caster.get_tree().create_timer(dash_time).timeout

	for i in strikes:
		# Either unit may have died, or the battle ended, while we were waiting.
		if not _alive(caster) or not caster.active or not _alive(target):
			return
		caster.attack_now(target)
		await caster.get_tree().create_timer(strike_interval).timeout


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive


## The furthest enemy that has a free cell next to it (or is already adjacent),
## and the cell to dash to. Returns an empty dictionary if there's none.
func _find_target(caster: BattleUnit) -> Dictionary:
	var origin := caster.global_position
	var enemies: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team:
			enemies.append(unit)
	# Furthest first.
	enemies.sort_custom(func(a, b): return origin.distance_squared_to(a.global_position) > origin.distance_squared_to(b.global_position))

	for enemy in enemies:
		if caster.grid.get_distance(caster.cell, enemy.cell) <= 1:
			return {"target": enemy, "cell": caster.cell}   # already adjacent, no dash needed
		var landing := _landing_cell(caster, enemy)
		if landing != NO_CELL:
			return {"target": enemy, "cell": landing}
	return {}


## The free cell next to `enemy` that is closest to the caster, or NO_CELL if none is free.
func _landing_cell(caster: BattleUnit, enemy: BattleUnit) -> Vector2i:
	var best := NO_CELL
	var best_dist := INF
	for dir in BattleGrid.DIRECTIONS:
		var cell: Vector2i = enemy.cell + dir
		if not caster.grid.can_place(cell):
			continue
		var dist := caster.global_position.distance_squared_to(caster.grid.cell_to_world(cell))
		if dist < best_dist:
			best_dist = dist
			best = cell
	return best
