class_name OverchargeEffect
extends Passive
## An Ascension effect (Obelisk, Overcharge; a chosen unit): it starts combat with Start
## Voltage, and each time it spends Voltage it gets Refund Share of it back.

@export var start_voltage: float = 20.0
@export var refund_share: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	if start_voltage > 0.0:
		VoltageStatus.ensure(unit).add(start_voltage)
	unit.add_status(OverchargeStatus.new(self))


class OverchargeStatus extends Status:
	var effect: OverchargeEffect

	func _init(p_effect: OverchargeEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_voltage_spent(unit: BattleUnit, amount: float) -> void:
		var voltage := VoltageStatus.of(unit)
		if voltage == null or amount <= 0.0:
			return
		voltage.stacks += amount * effect.refund_share   # a refund, not a gain: no boosts
		voltage._show()
