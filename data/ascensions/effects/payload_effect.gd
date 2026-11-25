class_name PayloadEffect
extends Passive
## An Ascension effect (Obelisk, Payload): a unit's Gambit damage gives Stacks of Mono-Virus,
## once per enemy for each Gambit it plays (multi-hit Gambits don't give it every tick).

@export var stacks: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(PayloadStatus.new(self))


class PayloadStatus extends Status:
	var effect: PayloadEffect
	var _infected: Dictionary = {}   # enemy instance ids infected by this Gambit

	func _init(p_effect: PayloadEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit(_unit: BattleUnit) -> void:
		_infected.clear()   # a new Gambit: every enemy can be infected again

	func on_gambit_damage(unit: BattleUnit, target: BattleUnit, amount: float) -> void:
		if amount <= 0.0 or not is_instance_valid(target) or not target.alive:
			return
		var id := target.get_instance_id()
		if _infected.has(id):
			return
		_infected[id] = true
		MonoVirusStatus.infect(target, effect.stacks, unit.get_credit_id())
