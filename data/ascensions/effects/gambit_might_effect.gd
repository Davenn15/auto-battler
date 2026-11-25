class_name GambitMightEffect
extends Passive
## An Ascension effect (Sword Court, Rising Valor): each time a unit plays its Gambit, it
## gains Might for the rest of combat (a permanent gain). The flat Might is the Ascension's.

@export var might_per_play: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GambitMightStatus.new(self))


class GambitMightStatus extends Status:
	var effect: GambitMightEffect

	func _init(p_effect: GambitMightEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_played(unit: BattleUnit) -> void:
		if unit.alive and effect.might_per_play > 0.0:
			unit.add_status(PermanentStatStatus.new(Stats.Stat.MIGHT, effect.might_per_play))
