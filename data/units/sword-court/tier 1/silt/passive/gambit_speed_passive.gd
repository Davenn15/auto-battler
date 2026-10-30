class_name GambitSpeedPassive
extends Passive
## Each time the unit Acts, it gains attack speed for the rest of the round.

## Celerity gained each time the unit uses its Gambit. At baseline 100, +15 is 15% faster.
@export var celerity_per_gambit: float = 15.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GambitSpeedStatus.new(celerity_per_gambit))
