class_name KillReserveEffect
extends Passive
## An Ascension effect (Von Carrow's hero Ascension): whenever the unit kills an enemy with
## direct damage (attacks, shots, Gambit hits), it rolls its Wrack Chance; on a success its
## player gains Amount Reserve after the combat. Only real combats pay out (see
## ArmySpawner.earn_reserve): the computer's test battles never do.

@export var amount: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BountyStatus.new(self))


class BountyStatus extends Status:
	const COLOR := Color(0.95, 0.78, 0.35)   # Reserve gold
	var effect: KillReserveEffect
	var _paid := {}   # enemies already rolled for, so one kill never rolls twice

	func _init(p_effect: KillReserveEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_direct_damage_dealt(unit: BattleUnit, target: BattleUnit, _amount: float) -> void:
		if not is_instance_valid(target) or target.alive or target.team == unit.team:
			return
		var id := target.get_instance_id()
		if _paid.has(id):
			return
		_paid[id] = true
		if CombatRng.randf() < unit.get_stat(Stats.Stat.WRACK_CHANCE):
			ArmySpawner.earn_reserve(unit.team, effect.amount)
			unit.show_float_text("+%d Reserve" % effect.amount, COLOR)
