class_name GritEffect
extends Passive
## An Ascension effect (Grit): every unit gains Amount Grit (see Grit). Stacks with other
## Grit, such as Bescard's.

@export_range(1.0, 100.0, 1.0) var amount: float = 20.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GritPassive.GritGain.new(amount))
