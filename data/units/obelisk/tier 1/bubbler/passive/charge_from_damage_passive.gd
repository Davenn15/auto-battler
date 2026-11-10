class_name ChargeFromDamagePassive
extends Passive
## Bubbler gains extra Charge from taking damage, of any kind (attacks, Gambits, damage over
## time), on top of the Charge every unit gets from being hit.

## Extra Charge per point of damage taken (0.03 = 3 Charge per 100 damage).
@export var charge_per_damage: float = 0.03


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ChargeFromDamageStatus.new(charge_per_damage))


class ChargeFromDamageStatus extends Status:
	var per_damage: float

	func _init(p_per_damage: float) -> void:
		per_damage = p_per_damage

	func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
		if damage > 0.0:
			unit.gain_charge(damage * per_damage)
		return damage
