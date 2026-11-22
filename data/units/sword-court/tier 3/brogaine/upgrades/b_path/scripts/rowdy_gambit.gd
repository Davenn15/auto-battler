class_name RowdyGambit
extends Gambit
## Brogaine B: singles out the enemy with the most max health and charges to it. For
## Duration seconds the two can only attack each other, neither gains Charge, and both
## take Reduction less damage from anyone else; Brogaine also gains Celerity Bonus. Immovability shortens the duel (both
## ends); at 100 or more the enemy ignores it and he only charges.

@export var duration: float = 5.0
## 0.75 = takes 75% less damage from anyone but the other duellist.
@export_range(0.0, 1.0, 0.05) var reduction: float = 0.75
## Celerity Brogaine gains for the duel.
@export var celerity_bonus: float = 40.0

const CHARGE_TIME := 0.35


func can_use(caster: BattleUnit) -> bool:
	return biggest_enemy(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var foe := biggest_enemy(caster)
	if foe == null:
		return
	caster.show_float_text("Rowdy!", BrogaineFx.COLOR)
	var dest := _charge_cell(caster, foe)
	if dest != caster.cell and not caster.is_immobile():
		caster.lock_for(CHARGE_TIME)
		caster.force_move(dest, CHARGE_TIME)
	var time := duration * foe.crowd_control_multiplier()
	if foe.is_cc_immune() or time <= 0.0:
		foe.show_float_text("Immune", BattleUnit.DODGE_COLOR)
		return
	var mine := DuelStatus.new(foe, time, reduction)
	var theirs := DuelStatus.new(caster, time, reduction)
	mine.celerity = celerity_bonus
	mine.other = theirs
	theirs.other = mine
	caster.add_status(mine)
	foe.add_status(theirs)
	BrogaineFx.duel(caster, foe, mine)


## The living, targetable enemy with the most max health (ties: the nearer, then the
## lower instance id).
static func biggest_enemy(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not caster._is_valid_target(enemy):
			continue
		if best == null or enemy.max_health > best.max_health:
			best = enemy
		elif is_equal_approx(enemy.max_health, best.max_health):
			var de := caster.grid.get_distance(caster.cell, enemy.cell)
			var db := caster.grid.get_distance(caster.cell, best.cell)
			if de < db or (de == db and enemy.get_instance_id() < best.get_instance_id()):
				best = enemy
	return best


## The free cell next to `foe` nearest Brogaine, or where he stands if he's already next
## to it or none is free.
func _charge_cell(caster: BattleUnit, foe: BattleUnit) -> Vector2i:
	var grid := caster.grid
	if grid.get_distance(caster.cell, foe.cell) <= caster.attack_range:
		return caster.cell
	var best := caster.cell
	var best_d := INF
	for cell in grid.free_cells_in_range(foe.cell, 1):
		var d := grid.cell_to_world(cell).distance_to(caster.global_position)
		if d < best_d:
			best_d = d
			best = cell
	return best


## On each duellist: it can only target the other, gains no Charge, and takes Reduction
## less damage from anyone else. Both ends come off together: when time runs out or
## either dies.
class DuelStatus extends Status:
	var foe   # untyped: may be freed
	var other: DuelStatus
	var time_left: float
	var reduction: float
	var celerity := 0.0   # Brogaine's end only

	func _init(p_foe: BattleUnit, p_time: float, p_reduction: float) -> void:
		foe = p_foe
		time_left = p_time
		reduction = p_reduction

	func on_applied(unit: BattleUnit) -> void:
		unit.move_status_to_front(self)   # cut damage before shields soak it
		unit.target = foe

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return true

	func modify_stat(_unit: BattleUnit, which: Stats.Stat, value: float) -> float:
		return value + celerity if which == Stats.Stat.CELERITY else value

	func modify_target_choice(_unit: BattleUnit, choice: BattleUnit, _exclude: BattleUnit) -> BattleUnit:
		return foe if _foe_alive() else choice

	func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
		if unit.incoming_attacker == foe and _foe_alive():
			return damage
		return damage * (1.0 - reduction)

	## Reduces damage, so Pure Damage skips it (see Status.reduces_damage).
	func reduces_damage(_unit: BattleUnit) -> bool:
		return true

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0 or not _foe_alive():
			end(unit)
			return
		if unit.target != foe:
			unit.target = foe   # whatever else picked a target, it's the duel

	func end(unit: BattleUnit) -> void:
		unit.remove_status(self)
		if other != null and _foe_alive_any() and foe.statuses.has(other):
			foe.remove_status(other)

	func _foe_alive() -> bool:
		return is_instance_valid(foe) and foe.alive

	func _foe_alive_any() -> bool:
		return is_instance_valid(foe)
