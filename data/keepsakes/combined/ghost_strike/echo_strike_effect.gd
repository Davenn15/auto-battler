class_name EchoStrikeEffect
extends Passive
## Ghost Strike: every few attacks, the attack's Hit Effects trigger an additional time
## (see Status.extra_hit_effect_runs). A ghostly echo of the swing shows when it happens.

@export var every: int = 3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Echo.new(every))


class Echo extends Status:
	var every: int
	var _count := 0
	var _echo := false   # this attack is the one that echoes

	func _init(p_every: int) -> void:
		every = p_every

	func on_attack(_unit: BattleUnit) -> void:
		_count += 1
		_echo = _count >= every
		if _echo:
			_count = 0

	func extra_hit_effect_runs(unit: BattleUnit) -> int:
		if not _echo:
			return 0
		_echo = false
		var target = unit.attack_target if is_instance_valid(unit.attack_target) else unit.target   # Beams don't set attack_target
		if is_instance_valid(target):
			KeepsakeVfx.ghost_strike(unit, target)
		return 1
