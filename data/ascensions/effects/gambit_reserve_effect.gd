class_name GambitReserveEffect
extends Passive
## An Ascension effect (Sumpton's hero Ascension): each time the unit finishes casting its
## Gambit (on either path), Chance to earn its player Amount Reserve, paid after the combat
## (see ArmySpawner.earn_reserve; the computer's test battles never pay).

@export_range(0.0, 1.0, 0.05) var chance: float = 0.35
@export var amount: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(RummageStatus.new(self))


class RummageStatus extends Status:
	const COLOR := Color(0.95, 0.78, 0.35)   # Reserve gold
	var effect: GambitReserveEffect

	func _init(p_effect: GambitReserveEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_finished(unit: BattleUnit) -> void:
		if CombatRng.randf() < effect.chance:
			ArmySpawner.earn_reserve(unit.team, effect.amount)
			unit.show_float_text("+%d Reserve" % effect.amount, COLOR)
