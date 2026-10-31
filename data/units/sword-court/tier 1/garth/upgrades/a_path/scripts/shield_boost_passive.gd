class_name ShieldBoostPassive
extends Passive
## Every shield the unit receives, from any source, is bigger.

## Extra shield as a fraction (0.3 = 30% bigger).
@export_range(0.0, 2.0, 0.05) var bonus: float = 0.3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ShieldBoostStatus.new(bonus))
