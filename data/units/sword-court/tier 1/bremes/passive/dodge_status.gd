class_name DodgeStatus
extends Status
## Adds to the unit's dodge chance for the whole battle.

var dodge_chance: float


func _init(p_dodge_chance: float) -> void:
	dodge_chance = p_dodge_chance


func modify_dodge_chance(_unit: BattleUnit, chance: float) -> float:
	return chance + dodge_chance
