class_name ShieldReductionPassive
extends Passive
## While the unit has a shield, it takes reduced damage.

## Fraction of incoming damage ignored while shielded (0.1 = 10%).
@export_range(0.0, 1.0, 0.01) var damage_reduction: float = 0.1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ShieldReductionStatus.new(damage_reduction))
