class_name PatientZeroEffect
extends Passive
## An Ascension effect (Obelisk, Patient Zero; a chosen unit): its first attack hit on each
## enemy gives Stacks of Mono-Virus.

@export var stacks: int = 2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(PatientZeroStatus.new(self))


class PatientZeroStatus extends Status:
	var effect: PatientZeroEffect
	var _seen: Dictionary = {}

	func _init(p_effect: PatientZeroEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_attack_hit(unit: BattleUnit, target: BattleUnit, _dealt: float) -> void:
		if not is_instance_valid(target) or not target.alive:
			return
		var id := target.get_instance_id()
		if _seen.has(id):
			return
		_seen[id] = true
		MonoVirusStatus.infect(target, effect.stacks, unit.get_credit_id())
