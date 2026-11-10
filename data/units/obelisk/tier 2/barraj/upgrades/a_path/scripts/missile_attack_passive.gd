class_name MissileAttackPassive
extends Passive
## BAR.RAJ A: each of his attacks also fires a missile that lands on a random point within
## Spread Cells of his target and explodes. Damage = Damage + Might Scaling x Might.
## The blast is the same size as his Barrage missiles (so A1 grows both).

@export var spread_cells: int = 1
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
		var target := unit.target
		if not is_instance_valid(target) or not target.alive:
			return
		var point := BarrageGambit.random_point(unit.grid, target.cell, passive.spread_cells)
		var amount := Stats.scaled(passive.damage, passive.might_scaling, unit.get_stat(Stats.Stat.MIGHT))
		BarrageGambit.fire(unit, point, _blast_cells(unit) * unit.grid.cell_spacing(), amount,
				passive.damage_type, 0, 0.0)


	func _blast_cells(unit: BattleUnit) -> float:
		var barrage := unit.gambit as BarrageGambit
		return barrage.blast_cells if barrage != null else passive.blast_cells
