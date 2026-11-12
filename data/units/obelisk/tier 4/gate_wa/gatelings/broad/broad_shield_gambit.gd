class_name BroadShieldGambit
extends Gambit
## Broad Gateling: shields the most hurt ally nearby (by share of max health, itself
## included) and every ally next to that one.
## Shield = Shield + Shield Insight Scaling x Insight.

@export var shield: float = 120.0
@export var shield_insight_scaling: float = 0.8
@export var duration: float = 4.0
## How far away the most hurt ally can be, in hex cells.
@export var range_cells: int = 4
## Allies within this many cells of that ally are shielded too.
@export var splash_cells: int = 1


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive or not caster.is_inside_tree():
		return
	var allies: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.active and unit.team == caster.team:
			allies.append(unit)
	var focus: BattleUnit = null
	for unit in allies:
		if caster.grid.get_distance(caster.cell, unit.cell) > range_cells:
			continue
		if focus == null or unit.health / unit.max_health < focus.health / focus.max_health:
			focus = unit
	if focus == null:
		return
	var amount := Stats.scaled(shield, shield_insight_scaling, caster.get_stat(Stats.Stat.INSIGHT))
	for unit in allies:
		if caster.grid.get_distance(focus.cell, unit.cell) <= splash_cells:
			unit.add_shield(amount, duration, caster.get_credit_id())
			KeepsakeVfx.ward_circle(unit, 0.6)
	caster.show_float_text("Bulwark", GateRules.LIGHT)
