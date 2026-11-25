class_name WrackerStunEffect
extends Passive
## Equalizer's Celerity Ward Empower: an enemy that Wracks the unit is stunned for Stun
## seconds, each enemy at most once per Cooldown seconds.

@export var stun: float = 0.75
@export var cooldown: float = 5.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Retort.new(self))


class Retort extends Status:
	var effect: WrackerStunEffect
	var _time := 0.0
	var _ready_at := {}

	func _init(p_effect: WrackerStunEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func tick(_unit: BattleUnit, delta: float) -> void:
		_time += delta

	func on_wracked_by(unit: BattleUnit, source: BattleUnit) -> void:
		if not is_instance_valid(source) or not source.alive or source.team == unit.team:
			return
		var id := source.get_instance_id()
		if _time < float(_ready_at.get(id, -1.0)):
			return
		_ready_at[id] = _time + effect.cooldown
		source.stun(effect.stun, unit)
