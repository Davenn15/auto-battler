class_name DashStrikeGambit
extends Gambit
## Dashes next to an enemy based on targeting rule, then attacks it several times in
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
enum TargetRule { FARTHEST, LOWEST_HEALTH, FARTHEST_UNLESS_FINISHING }

## Which enemy to dash to: the farthest one, or the one with the lowest share of its max
## health (ties, like everyone at full health, go to the farthest).
@export var target_rule: TargetRule = TargetRule.FARTHEST

## With FARTHEST_UNLESS_FINISHING: if the current target is at or below this share of its
## max health, strike it instead of dashing away (0.5 = half).
@export_range(0.0, 1.0) var finish_threshold: float = 0.5

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
			caster.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).tween_property(caster, "global_position", end, dash_time)
			await caster.get_tree().create_timer(dash_time, true, true).timeout

	for i in strikes:
		# Either unit may have died, or the battle ended, while we were waiting.
		if not _alive(caster) or not caster.active or not _alive(target):
			return
		caster.attack_now(target)
		await caster.get_tree().create_timer(strike_interval, true, true).timeout


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
	enemies.sort_custom(_comes_first.bind(origin))
	if target_rule == TargetRule.FARTHEST_UNLESS_FINISHING and _is_finishable(caster, caster.target):
		enemies.erase(caster.target)
		enemies.push_front(caster.target)   # tried first; the rest stay farthest first
	for enemy in enemies:
		if caster.grid.get_distance(caster.cell, enemy.cell) <= 1:
			return {"target": enemy, "cell": caster.cell}   # already adjacent, no dash needed
		var landing := _landing_cell(caster, enemy)
		if landing != NO_CELL:
			return {"target": enemy, "cell": landing}
	return {}

## Sort order for targets: by `target_rule`, then farthest first.
func _comes_first(a: BattleUnit, b: BattleUnit, origin: Vector2) -> bool:
	if target_rule == TargetRule.LOWEST_HEALTH:
		var a_share := a.health / a.max_health
		var b_share := b.health / b.max_health
		if not is_equal_approx(a_share, b_share):
			return a_share < b_share
	return origin.distance_squared_to(a.global_position) > origin.distance_squared_to(b.global_position)

## True if `unit` is a living enemy at or below `finish_threshold` of its max health.
## Untyped because the caster's target may have been freed.
func _is_finishable(caster: BattleUnit, unit) -> bool:
	return _alive(unit) and unit.team != caster.team and unit.health <= unit.max_health * finish_threshold

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
