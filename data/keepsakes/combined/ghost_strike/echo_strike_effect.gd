class_name EchoStrikeEffect
extends Passive
## Every few attacks, the unit attacks again straight away.

@export var every: int = 4


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Echo.new(every))


class Echo extends Status:
	var every: int
	var _count := 0
	var _pending := false
	var _echoing := false   # true during the extra attack, so it doesn't count itself

	func _init(p_every: int) -> void:
		every = p_every

	func on_attack(_unit: BattleUnit) -> void:
		if _echoing:
			return
		_count += 1
		if _count >= every:
			_count = 0
			_pending = true

	func tick(unit: BattleUnit, _delta: float) -> void:
		if not _pending:
			return
		_pending = false
		if unit.active and unit._is_valid_target(unit.target):
			_echoing = true
			# The ghost draws this attack's swing instead of the unit.
			KeepsakeVfx.ghost_strike(unit, unit.target)
			unit.hide_next_swing = KeepsakeVfx.enabled()
			unit.bonus_attack(unit.target)
			unit.hide_next_swing = false
			_echoing = false
