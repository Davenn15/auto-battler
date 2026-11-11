class_name MalletSlamGambit
extends Gambit
## MALLET leaps to the spot that hits the most enemies and slams down, hurting every enemy
## within Radius. Damage is highest next to where it lands and falls off towards the edge.
## Damage = Damage + Might Scaling x Might, times the falloff share.
##   A (Devastating): the slam also stuns, longer closer to the center.
##   A1: MALLET Phases for a while after landing.
##   A2: the slam ignores a share of enemy wards.

## How far MALLET can leap, in hex cells.
@export var leap_range_cells: int = 4
## How far the slam reaches from where it lands, in hex cells.
@export var radius_cells: int = 2
## Seconds MALLET spends in the air (untargetable).
@export var air_time: float = 0.6
## How high it flies on screen, in pixels.
@export var leap_height: float = 48.0
@export var damage: float = 140.0
@export var might_scaling: float = 1.0
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## Share of the damage enemies at the edge take (0.5 = half). Enemies next to MALLET take all of it.
@export_range(0.0, 1.0, 0.05) var edge_share: float = 0.5
## A: stun seconds next to MALLET and at the edge. 0 = no stun.
@export var stun_center: float = 0.0
@export var stun_edge: float = 0.0
## A1: seconds MALLET Phases after landing. 0 = none.
@export var phase_after: float = 0.0
## A2: share of enemy wards the slam ignores (0.4 = 40%).
@export_range(0.0, 1.0, 0.05) var ward_ignore: float = 0.0


## Only leaps if some landing spot would hit an enemy.
func can_use(caster: BattleUnit) -> bool:
	return _best_cell(caster)["count"] > 0


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var spot := _best_cell(caster)
	if spot["count"] == 0:
		return
	caster.show_float_text("Slam", MalletFx.LIGHT)
	await MalletFx.leap(caster, spot["cell"], air_time, leap_height)
	if not _alive(caster) or not caster.active or not caster.is_inside_tree():
		return
	MalletFx.shockwave(caster, radius_cells)
	var hit := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	# Items can let Gambit damage wrack: one roll for the whole slam.
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	for enemy in enemies_in_reach(caster):
		var t := falloff(caster.grid.get_distance(caster.cell, enemy.cell))
		var dealt := hit_enemy(caster, enemy, hit * lerpf(1.0, edge_share, t), wrack, damage_type, ward_ignore)
		var stun := lerpf(stun_center, stun_edge, t)
		if stun > 0.0 and dealt > 0.0 and enemy.alive:
			enemy.stun(stun, caster)
	MalletFx.self_phase(caster, phase_after)


## 0 next to MALLET, 1 at the edge of the slam.
func falloff(distance: int) -> float:
	if radius_cells <= 1:
		return 0.0
	return clampf(float(distance - 1) / float(radius_cells - 1), 0.0, 1.0)


## Deals Gambit damage to `enemy`, ignoring `ignore` of its wards (0.4 = 40%), and credits
## it to the caster. Returns what was dealt.
static func hit_enemy(caster: BattleUnit, enemy: BattleUnit, amount: float, wrack: int,
		type: int, ignore: float) -> float:
	var skip_wards := false
	if ignore > 0.0:
		var ward := enemy.get_stat(Stats.ward_stat_for(type))
		for status in caster.statuses:
			ward = status.modify_target_ward(caster, enemy, ward, wrack)
		amount *= Stats.ward_multiplier(ward * (1.0 - ignore))
		skip_wards = true   # already applied, at the lowered value
	var dealt := enemy.take_damage(amount, wrack, type, skip_wards, caster)
	caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)
	return dealt


func enemies_in_reach(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team \
				and caster.grid.get_distance(caster.cell, unit.cell) <= radius_cells:
			result.append(unit)
	return result


## The cell within leap range (or MALLET's own) whose slam hits the most enemies. Ties go
## to the one with more enemies near the center, then to the nearest.
## Returns {"cell": Vector2i, "count": enemies it would hit}.
func _best_cell(caster: BattleUnit) -> Dictionary:
	var grid := caster.grid
	var enemies: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team:
			enemies.append(unit)
	var cells := grid.free_cells_in_range(caster.cell, leap_range_cells)
	cells.append(caster.cell)
	cells.sort_custom(func(a, b): return grid.get_distance(caster.cell, a) < grid.get_distance(caster.cell, b))
	var best := {"cell": caster.cell, "count": 0, "weight": 0.0}
	for cell in cells:
		var count := 0
		var weight := 0.0
		for enemy in enemies:
			var distance := grid.get_distance(cell, enemy.cell)
			if distance <= radius_cells:
				count += 1
				weight += lerpf(1.0, edge_share, falloff(distance))
		if count > best["count"] or (count == best["count"] and weight > best["weight"] + 0.001):
			best = {"cell": cell, "count": count, "weight": weight}
	return best


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive
