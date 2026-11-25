class_name CapacitorShellEffect
extends Passive
## An Ascension effect (Obelisk, Capacitor Shell): units start combat with Start Voltage, and
## whenever one spends Voltage (its Gambit clearing it, or a Gambit using it) it gains a
## Shield of Shield Per Voltage for each Voltage spent, for Shield Duration seconds.

@export var start_voltage: float = 5.0
@export var shield_per_voltage: float = 10.0
@export var shield_duration: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	if start_voltage > 0.0:
		VoltageStatus.ensure(unit).add(start_voltage)
	unit.add_status(CapacitorStatus.new(self))


class CapacitorStatus extends Status:
	var effect: CapacitorShellEffect

	func _init(p_effect: CapacitorShellEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_voltage_spent(unit: BattleUnit, amount: float) -> void:
		if unit.alive and amount > 0.0:
			unit.add_shield(amount * effect.shield_per_voltage, effect.shield_duration, unit.get_instance_id())
