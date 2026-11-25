class_name UndyingCodeEffect
extends Passive
## An Ascension effect (Obelisk, Undying Code): units that have Revived gain Might and
## Vampirism.

@export var might: float = 40.0
## 0.15 = 15%.
@export var vampirism: float = 0.15


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(UndyingStatus.new(self))


class UndyingStatus extends Status:
	var effect: UndyingCodeEffect

	func _init(p_effect: UndyingCodeEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if not Revive.is_revived(unit):
			return value
		match stat:
			Stats.Stat.MIGHT:
				return value + effect.might
			Stats.Stat.VAMPIRISM:
				return value + effect.vampirism
		return value
