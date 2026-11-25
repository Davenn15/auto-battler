class_name NonAttackDodgeEffect
extends Passive
## Eel Sash's Insight Ward Empower: +Chance dodge against damage that isn't an attack
## (Gambit damage and other effects; Pure Damage can never be dodged).

@export var chance: float = 0.15


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Slip.new(self))


class Slip extends Status:
	var effect: NonAttackDodgeEffect

	func _init(p_effect: NonAttackDodgeEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_dodge_chance(unit: BattleUnit, chance: float) -> float:
		return chance + effect.chance if unit.taking_hit and unit.dodging_attacker == null else chance
