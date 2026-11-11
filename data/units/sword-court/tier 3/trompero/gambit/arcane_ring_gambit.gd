class_name ArcaneRingGambit
extends Gambit
## Places a ring where it covers the most enemies. It deals Insight damage every half
## second while it lasts, then explodes for a final burst that stuns everyone inside.
## Each damage value = base + Insight Scaling x the caster's Insight, fixed when cast.

## How far from the caster the ring can be placed, in hex cells.
@export var cast_range_cells: int = 5
## Ring size in hex cells. 1 = the center cell plus the six around it.
@export var radius_cells: int = 1
## Seconds the ring ticks before it explodes.
@export var duration: float = 3.0
@export var tick_damage: float = 20.0
@export var tick_insight_scaling: float = 0.1
@export var burst_damage: float = 80.0
@export var burst_insight_scaling: float = 0.5
## Seconds enemies are stunned by the explosion.
@export var stun_time: float = 0.75
## Lets ring damage wrack, using the caster's wrack chance and wrack damage.
@export var can_wrack: bool = false
## Insight enemies lose while standing in the ring. 0 = none.
@export var insight_drain: float = 0.0
## Charge the caster gains for each enemy the final explosion damages. 0 = none.
@export var charge_per_burst_hit: float = 0.0
## The caster can't gain Charge from casting until the ring explodes.
@export var no_charge_until_burst: bool = true


## Only casts if there's an enemy in reach, so charge isn't wasted.
func can_use(caster: BattleUnit) -> bool:
	return not _enemies_in_reach(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	# Enemies may have moved or died during the Act time, so look again now.
	var candidates := _enemies_in_reach(caster)
	if candidates.is_empty():
		return
	var insight := caster.get_stat(Stats.Stat.INSIGHT)
	var ring := ArcaneRing.new()
	ring.setup(caster, _best_center(caster, candidates), radius_cells, duration,
			Stats.scaled(tick_damage, tick_insight_scaling, insight),
			Stats.scaled(burst_damage, burst_insight_scaling, insight),
			stun_time, Stats.DamageType.INSIGHT)
	# Wracks if A lets it or an item does; when it could already, items add wrack damage.
	var ring_wracks := can_wrack or caster.can_wrack_kind(Stats.EffectKind.GAMBIT_DAMAGE)
	ring.wrack_chance = caster.get_stat(Stats.Stat.WRACK_CHANCE) if ring_wracks else 0.0
	ring.wrack_multiplier = caster.effect_wrack_multiplier(1, Stats.EffectKind.GAMBIT_DAMAGE, can_wrack)   # per level
	ring.insight_drain = insight_drain * caster.wrack_effect_multiplier(Stats.EffectKind.CONTROL)
	ring.charge_per_burst_hit = charge_per_burst_hit
	if no_charge_until_burst:
		ring.charge_lock = ArcaneRing.ChargeLock.new()
		caster.add_status(ring.charge_lock)
	caster.get_tree().current_scene.add_child(ring)
	ring.global_position = caster.grid.cell_to_world(ring.center)


func _living_enemies(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team:
			result.append(unit)
	return result


func _enemies_in_reach(caster: BattleUnit) -> Array[BattleUnit]:
	return _living_enemies(caster).filter(
			func(e): return caster.grid.get_distance(caster.cell, e.cell) <= cast_range_cells)


## Tries centering the ring on each enemy in reach and keeps the cell that covers the most
## enemies. Nearer enemies are tried first, so ties go to the closest one.
func _best_center(caster: BattleUnit, candidates: Array[BattleUnit]) -> Vector2i:
	var grid := caster.grid
	var all_enemies := _living_enemies(caster)
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a, b): return grid.get_distance(caster.cell, a.cell) < grid.get_distance(caster.cell, b.cell))
	var best: Vector2i = sorted[0].cell
	var best_count := -1
	for enemy in sorted:
		var count := 0
		for other in all_enemies:
			if grid.get_distance(enemy.cell, other.cell) <= radius_cells:
				count += 1
		if count > best_count:
			best_count = count
			best = enemy.cell
	return best
