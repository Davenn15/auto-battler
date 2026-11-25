class_name VoltageBoostPassive
extends Passive
## Vestibule A1: all Voltage the unit gains is Bonus higher (0.5 = 50% more).

@export var bonus: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(VoltageBoostStatus.new(self))


class VoltageBoostStatus extends Status:
	var passive: VoltageBoostPassive

	func _init(p_passive: VoltageBoostPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_voltage_gain(_unit: BattleUnit, amount: float) -> float:
		return amount * (1.0 + passive.bonus)
