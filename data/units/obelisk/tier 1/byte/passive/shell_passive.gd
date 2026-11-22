class_name ByteShellPassive
extends Passive
## BYTE: while above Health Threshold of its max health, each of its Wards is higher by
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

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if WARDS.has(stat) and unit.max_health > 0.0 \
				and unit.health > unit.max_health * passive.health_threshold:
			return value + passive.ward_bonus
		return value
