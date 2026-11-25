class_name GloryTriggerEffect
extends Passive
## An Ascension effect (Sword Court's Glory triggers): the first unit in the army to reach
## Count of something in a combat gains Glory (if it can still gain one this combat). Once
## per combat for the whole army: after that, no other unit gains Glory from it. Army
## units only: summons don't keep Glory, so they're left out.
##   KILLS: kills (any direct damage that finishes an enemy).
##   ATTACKS: attacks made.
##   CASTS: Gambit plays finished.

enum Trigger { KILLS, ATTACKS, CASTS }
@export var trigger: Trigger = Trigger.KILLS
@export var count: int = 3


func on_battle_start(unit: BattleUnit) -> void:
	if unit.is_summon:
		return
	_given(unit)[_key(unit)] = false   # every army unit starts before any can count
	unit.add_status(TriggerStatus.new(self))


## Where the army's "already given this combat" marks live: on the combat's board, so
## battles running side by side (sims) and the two teams each keep their own.
static func _given(unit: BattleUnit) -> Dictionary:
	var board: Node = unit.grid if unit.grid != null else unit.get_parent()
	if not board.has_meta("glory_triggers"):
		board.set_meta("glory_triggers", {})
	return board.get_meta("glory_triggers")


func _key(unit: BattleUnit) -> Array:
	return [get_instance_id(), unit.team]


func _spent(unit: BattleUnit) -> bool:
	return bool(_given(unit).get(_key(unit), false))


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
		if _done or effect._spent(unit):
			return
		_progress += 1
		if _progress >= effect.count:
			_done = true
			GloryTriggerEffect._given(unit)[effect._key(unit)] = true   # the army's one
			unit.gain_glory()
