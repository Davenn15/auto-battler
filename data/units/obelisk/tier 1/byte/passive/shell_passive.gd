class_name ByteShellPassive
extends Passive
## Byte: while above Health Threshold of its max health, each of its Wards is higher by
## Ward Bonus.

@export var ward_bonus: float = 20.0
@export_range(0.0, 1.0, 0.05) var health_threshold: float = 0.6


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ShellStatus.new(self))


class ShellStatus extends Status:
	const WARDS := [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]
	var passive: ByteShellPassive

	func _init(p_passive: ByteShellPassive) -> void:
		passive = p_passive

	var _shown := false   # the shell is drawn (the Wards are up)

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func _up(unit: BattleUnit) -> bool:
		return unit.max_health > 0.0 and unit.health > unit.max_health * passive.health_threshold

	func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if WARDS.has(stat) and _up(unit):
			return value + passive.ward_bonus
		return value

	## The look: a thin deep blue shell over Byte while the Wards are up. It breaks when
	## Byte drops to the threshold and reforges if it heals back above it.
	func on_applied(unit: BattleUnit) -> void:
		_shown = _up(unit)
		ByteFx.shell(unit, _shown, false)

	func tick(unit: BattleUnit, _delta: float) -> void:
		var up := _up(unit) and unit.alive
		if up != _shown:
			_shown = up
			ByteFx.shell(unit, up, true)

	func on_removed(unit: BattleUnit) -> void:
		ByteFx.shell(unit, false, false)
