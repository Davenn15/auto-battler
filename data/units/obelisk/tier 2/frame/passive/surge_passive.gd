class_name FrameSurgePassive
extends Passive
## Frame: after it casts its Gambit (either path's), it gains Celerity and each Ward for
## Duration seconds. Casting again starts the timer over.

@export var celerity: float = 40.0
@export var ward_bonus: float = 25.0
@export var duration: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(SurgeWatch.new(self))


class SurgeWatch extends Status:
	var passive: FrameSurgePassive

	func _init(p_passive: FrameSurgePassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_finished(unit: BattleUnit) -> void:
		for status in unit.statuses:
			if status is Surge:
				status.time_left = passive.duration   # a fresh window
				return
		unit.add_status(Surge.new(passive))


class Surge extends Status:
	var passive: FrameSurgePassive
	var time_left: float

	func _init(p_passive: FrameSurgePassive) -> void:
		passive = p_passive
		time_left = p_passive.duration

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		match stat:
			Stats.Stat.CELERITY:
				return value + passive.celerity
			Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD:
				return value + passive.ward_bonus
		return value

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			unit.remove_status(self)
