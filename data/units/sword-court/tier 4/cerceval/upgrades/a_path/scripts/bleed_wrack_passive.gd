class_name BleedWrackPassive
extends Passive
## Cerceval A1: Wrack Chance rises with the Bleed on enemies within his attack range: +Per
## Step for every Step of Bleed in their pools added together, up to Cap.

@export var step: float = 50.0
@export var per_step: float = 0.01
@export var cap: float = 0.3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BleedWrackStatus.new(self))


class BleedWrackStatus extends Status:
	var passive: BleedWrackPassive

	func _init(p_passive: BleedWrackPassive) -> void:
		passive = p_passive

	func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat != Stats.Stat.WRACK_CHANCE or not unit.is_inside_tree():
			return value
		var total := 0.0
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy != null and enemy.alive and enemy.team != unit.team \
					and unit.grid.get_distance(unit.cell, enemy.cell) <= unit.attack_range:
				total += Bleed.amount_on(enemy)
		return value + minf(floorf(total / passive.step) * passive.per_step, passive.cap)
