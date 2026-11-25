class_name GloryWrackEffect
extends Passive
## An Ascension effect (Sword Court, Glorious Fury): each unit gains Wrack Chance and Wrack
## Damage for every stack of Glory it has (from earlier fights and this one).

## 0.05 = +5% per Glory.
@export var wrack_chance_per_glory: float = 0.05
@export var wrack_damage_per_glory: float = 0.05


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GloryWrackStatus.new(self))


class GloryWrackStatus extends Status:
	var effect: GloryWrackEffect

	func _init(p_effect: GloryWrackEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		var glory := unit.glory + unit.glory_gained
		if glory <= 0:
			return value
		match stat:
			Stats.Stat.WRACK_CHANCE:
				return value + effect.wrack_chance_per_glory * glory
			Stats.Stat.WRACK_DAMAGE:
				return value + effect.wrack_damage_per_glory * glory
		return value
