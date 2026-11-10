class_name MaxChargePassive
extends Passive
## Changes how much Charge the unit's Gambit needs, for the whole battle.

## Added to max Charge (negative = casts sooner).
@export var change: float = -30.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.set_max_charge(unit.max_charge + change)
