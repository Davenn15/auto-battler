class_name ManalyzerEffect
extends Passive
## Manalyzer: whenever the unit's Gambit heals or shields a unit, that unit gains Charge
## (Self Charge if it's the unit itself), at most once per Cooldown seconds per unit.
##   Health Empower: the unit's Gambit heals and shields are Support Bonus bigger and last
##   Duration Bonus longer.

@export var charge: float = 10.0
@export var self_charge: float = 5.0
@export var cooldown: float = 1.0
@export var support_bonus: float = 0.0
@export var duration_bonus: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Analyzer.new(self))


class Analyzer extends Status:
	var effect: ManalyzerEffect
	var _time := 0.0
	var _ready_at := {}   # unit instance id -> time it can get Charge again

	func _init(p_effect: ManalyzerEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func tick(_unit: BattleUnit, delta: float) -> void:
		_time += delta

	func on_support_given(unit: BattleUnit, target: BattleUnit, _is_shield: bool, by_gambit: bool) -> void:
		if not by_gambit or not is_instance_valid(target) or not target.alive:
			return
		var id := target.get_instance_id()
		if _time < float(_ready_at.get(id, -1.0)):
			return
		_ready_at[id] = _time + effect.cooldown
		target.gain_charge(effect.self_charge if target == unit else effect.charge)

	func modify_outgoing_support(_unit: BattleUnit, _target: BattleUnit, amount: float, _is_shield: bool, by_gambit: bool) -> float:
		return amount * (1.0 + effect.support_bonus) if by_gambit else amount

	func modify_support_duration(_unit: BattleUnit, _target: BattleUnit, duration: float, by_gambit: bool) -> float:
		return duration * (1.0 + effect.duration_bonus) if by_gambit else duration
