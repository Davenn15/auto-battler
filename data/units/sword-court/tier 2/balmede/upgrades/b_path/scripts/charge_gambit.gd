class_name BalmedeChargeGambit
extends Gambit
## Balmede B: charges in a straight line at the farthest enemy within Range Cells and on
## through it, ending in the free cell nearest one cell beyond it. Every enemy she passes
## (the one she aimed at included) takes Damage + Might Scaling x Might and is stunned.
##   B2: more range.

@export var damage: float = 60.0
@export var might_scaling: float = 0.5
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
@export var range_cells: int = 4
@export var stun_duration: float = 0.75

## Seconds the charge takes, end to end.
const CHARGE_TIME := 0.5
const NO_CELL := Vector2i(-9999, -9999)


func can_use(caster: BattleUnit) -> bool:
	return _pick(caster).size() > 0


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var found := _pick(caster)
	if found.is_empty():
		return
	var dest: Vector2i = found["cell"]
	var start := caster.global_position
	var end := caster.grid.cell_to_world(dest)
	# Who she'll run through, each with how far along the charge she reaches them (0 to 1).
	var passed := _enemies_on_path(caster, start, end)
	caster.lock_for(CHARGE_TIME)
	BalmedeFx.charge_trail(caster, start, CHARGE_TIME)
	caster.force_move(dest, CHARGE_TIME)
	var hit := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	var elapsed := 0.0
	while not passed.is_empty():
		# Once she's arrived, anyone still listed is struck (never left waiting).
		var progress := elapsed / CHARGE_TIME if elapsed < CHARGE_TIME else INF
		for entry in passed.duplicate():
			if entry["at"] <= progress:
				passed.erase(entry)
				_strike(caster, entry["enemy"], hit)
		if passed.is_empty():
			break
		await caster.get_tree().physics_frame
		if not _alive(caster):
			return
		elapsed += caster.get_physics_process_delta_time()


## One enemy she runs through: the hit, then the stun.
func _strike(caster: BattleUnit, enemy, hit: float) -> void:
	if not _alive(enemy) or not _alive(caster) or not caster.active:
		return   # someone died, or the battle ended mid-charge
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	var amount := hit * caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	var dealt: float = enemy.take_damage(BattleUnit.damage_bonus(caster, enemy, amount), wrack, damage_type)
	BattleUnit.gambit_damage_dealt(caster, enemy, dealt)
	caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_instance_id(), dealt)
	if _alive(enemy):
		enemy.stun(stun_duration, caster)


## The farthest targetable enemy within reach that has a landing cell beyond it, and that
## cell: {"target", "cell"}, or empty if there's none.
func _pick(caster: BattleUnit) -> Dictionary:
	var enemies: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy != null and caster._is_valid_target(enemy) \
				and caster.grid.get_distance(caster.cell, enemy.cell) <= range_cells:
			enemies.append(enemy)
	# Farthest first; ties by instance id so the order never depends on the tree's.
	enemies.sort_custom(func(a: BattleUnit, b: BattleUnit):
		var da := caster.grid.get_distance(caster.cell, a.cell)
		var db := caster.grid.get_distance(caster.cell, b.cell)
		return da > db if da != db else a.get_instance_id() < b.get_instance_id())
	for enemy in enemies:
		var cell := _landing(caster, enemy)
		if cell != NO_CELL:
			return {"target": enemy, "cell": cell}
	return {}


## The free cell (within 2 of `enemy`) nearest the point one cell past it, on the line from
## Balmede through it. It must be at least as far from her as the enemy is, so she really
## goes through rather than stopping short.
func _landing(caster: BattleUnit, enemy: BattleUnit) -> Vector2i:
	var grid := caster.grid
	var dir := (enemy.global_position - caster.global_position).normalized()
	var beyond := enemy.global_position + dir * grid.cell_spacing()
	var reach := grid.get_distance(caster.cell, enemy.cell)
	var best := NO_CELL
	var best_d := INF
	for cell in grid.free_cells_in_range(enemy.cell, 2):
		if grid.get_distance(caster.cell, cell) < reach:
			continue
		var d := grid.cell_to_world(cell).distance_to(beyond)
		if d < best_d:
			best_d = d
			best = cell
	return best


## Living enemies within half a cell of her path, as {"enemy", "at"}: "at" is how far along
## the path (0 to 1) she reaches them.
func _enemies_on_path(caster: BattleUnit, from: Vector2, to: Vector2) -> Array:
	var result := []
	var width := caster.grid.cell_spacing() * 0.5
	var length_sq := maxf(from.distance_squared_to(to), 0.0001)
	for node in caster.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not caster._is_valid_target(enemy):
			continue
		var p := Geometry2D.get_closest_point_to_segment(enemy.global_position, from, to)
		if p.distance_to(enemy.global_position) <= width:
			result.append({"enemy": enemy, "at": (p - from).dot(to - from) / length_sq})
	return result


func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive
