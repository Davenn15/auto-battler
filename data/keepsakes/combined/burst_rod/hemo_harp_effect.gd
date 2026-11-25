class_name HemoHarpEffect
extends Passive
## Hemo-Harp: the unit's Gambit damage also inflicts Bleed for Share of the damage dealt.
## Insight Empower: +1 Insight per (1 / Insight Per Bleed) Bleed on enemies within Radius
## Cells, up to Insight Cap.

@export_range(0.0, 2.0, 0.05) var share: float = 0.3
## Insight per point of Bleed on nearby enemies (0.05 = 1 per 20). 0 = none.
@export var insight_per_bleed: float = 0.0
@export var insight_cap: float = 50.0
@export var radius_cells: int = 2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Harp.new(self))


class Harp extends Status:
	var effect: HemoHarpEffect
	var _insight := 0.0
	var _check := 0.0

	func _init(p_effect: HemoHarpEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_damage(unit: BattleUnit, target: BattleUnit, amount: float) -> void:
		if target.alive and effect.share > 0.0:
			Bleed.apply(target, amount * effect.share, unit, false)   # worked out from damage dealt

	func tick(unit: BattleUnit, delta: float) -> void:
		if effect.insight_per_bleed <= 0.0:
			return
		_check -= delta
		if _check > 0.0:
			return
		_check = 0.25   # the Bleed nearby, a few times a second
		var total := 0.0
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy != null and enemy.alive and enemy.team != unit.team \
					and unit.grid.get_distance(unit.cell, enemy.cell) <= effect.radius_cells:
				total += Bleed.amount_on(enemy)
		_insight = minf(floorf(total * effect.insight_per_bleed), effect.insight_cap)

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + _insight if stat == Stats.Stat.INSIGHT else value
