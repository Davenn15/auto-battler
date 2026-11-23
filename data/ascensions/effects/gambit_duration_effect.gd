class_name GambitDurationEffect
extends Passive
## An Ascension effect (Glaive's hero Ascension): the unit's Gambit lasts Multiplier times
## as long, whichever Gambit it has (anything with a `duration`: Glaive's Rotor or his
## Serrated spin). The unit gets its own copy of the Gambit, so the shared file is untouched.

@export var multiplier: float = 2.0


func on_battle_start(unit: BattleUnit) -> void:
	if unit.gambit == null or not ("duration" in unit.gambit):
		return
	unit.gambit = unit.gambit.duplicate() as Gambit
	unit.gambit.duration *= multiplier
