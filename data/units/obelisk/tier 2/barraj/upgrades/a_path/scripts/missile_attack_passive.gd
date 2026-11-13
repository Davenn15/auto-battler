class_name MissileAttackPassive
extends Passive
## BAR.RAJ A: each of his attacks also fires a missile at a random enemy within his attack
## range, which follows it and explodes on it. Damage = Damage + Might Scaling x Might.
## The blast is the same size as his Barrage missiles (so A1 grows both).

## Blast size, in hex cells, used only if his Gambit isn't Barrage.
@export var blast_cells: float = 0.8
@export var damage: float = 40.0
@export var might_scaling: float = 0.3
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(MissileAttackStatus.new(self))


class MissileAttackStatus extends Status:
	var passive: MissileAttackPassive

	func _init(p_passive: MissileAttackPassive) -> void:
		passive = p_passive

	func on_attack(unit: BattleUnit) -> void:
		var enemies: Array = []
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy != null and enemy.alive and enemy.team != unit.team and enemy.is_targetable() \
					and unit.grid.get_distance(unit.cell, enemy.cell) <= unit.attack_range:
				enemies.append(enemy)
		if enemies.is_empty():
			return
		var target: BattleUnit = CombatRng.pick(enemies)
		var amount := Stats.scaled(passive.damage, passive.might_scaling, unit.get_stat(Stats.Stat.MIGHT))
		BarrageGambit.fire(unit, target, _blast_cells(unit) * unit.grid.cell_spacing(), amount,
				passive.damage_type, 0, 0.0)


	func _blast_cells(unit: BattleUnit) -> float:
		var barrage := unit.gambit as BarrageGambit
		return barrage.blast_cells if barrage != null else passive.blast_cells
