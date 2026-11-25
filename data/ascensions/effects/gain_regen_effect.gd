class_name GainRegenEffect
extends Passive
## An Ascension effect (Sword Court, Second Breath; a chosen unit): each time the unit gains
## permanent stats it gains Regen health per second for Duration seconds. Each gain adds its
## own timer, so they stack. Several stats gained at once (Glory, a Sumpton blade) are one gain.

@export var regen: float = 10.0
@export var duration: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GainRegenStatus.new(self))


class GainRegenStatus extends Status:
	var effect: GainRegenEffect
	var _timers: Array[float] = []
	var _last_frame := -1

	func _init(p_effect: GainRegenEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_permanent_stats_gained(_unit: BattleUnit, _gains: Dictionary) -> void:
		var frame := Engine.get_physics_frames()
		if frame == _last_frame:
			return   # the same gain, one stat at a time
		_last_frame = frame
		_timers.append(effect.duration)

	func tick(_unit: BattleUnit, delta: float) -> void:
		for i in range(_timers.size() - 1, -1, -1):
			_timers[i] -= delta
			if _timers[i] <= 0.0:
				_timers.remove_at(i)

	func modify_health_regen(_unit: BattleUnit, regen: float) -> float:
		return regen + effect.regen * _timers.size()
