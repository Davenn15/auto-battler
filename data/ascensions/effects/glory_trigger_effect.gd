class_name GloryTriggerEffect
extends Passive
## An Ascension effect (Sword Court's Glory triggers): the first time each combat a unit in
## the army reaches Count of something, it gains Glory (if it can still gain one this
## combat). Army units only: summons don't keep Glory, so they're left out.
##   KILLS: kills (any direct damage that finishes an enemy).
##   ATTACKS: attacks made.
##   CASTS: Gambit casts finished.

enum Trigger { KILLS, ATTACKS, CASTS }
@export var trigger: Trigger = Trigger.KILLS
@export var count: int = 3


func on_battle_start(unit: BattleUnit) -> void:
	if unit.is_summon:
		return
	unit.add_status(TriggerStatus.new(self))


class TriggerStatus extends Status:
	var effect: GloryTriggerEffect
	var _progress := 0
	var _done := false
	var _killed := {}   # enemies already counted, so one kill never counts twice

	func _init(p_effect: GloryTriggerEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_direct_damage_dealt(unit: BattleUnit, target: BattleUnit, _amount: float) -> void:
		if effect.trigger != Trigger.KILLS or not is_instance_valid(target) or target.alive or target.team == unit.team:
			return
		if _killed.has(target.get_instance_id()):
			return
		_killed[target.get_instance_id()] = true
		_count(unit)

	func on_attack(unit: BattleUnit) -> void:
		if effect.trigger == Trigger.ATTACKS:
			_count(unit)

	func on_gambit_finished(unit: BattleUnit) -> void:
		if effect.trigger == Trigger.CASTS:
			_count(unit)

	func _count(unit: BattleUnit) -> void:
		if _done:
			return
		_progress += 1
		if _progress >= effect.count:
			_done = true
			unit.gain_glory()
