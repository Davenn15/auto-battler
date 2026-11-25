class_name ByteRupturedPassive
extends Passive
## Byte A (Ruptured): whenever Byte is healed (Regeneration included), it also gains Shield
## Share of the health it actually gained as a shield lasting Duration seconds. It's one
## shield: each heal adds to it and starts its timer over.

@export_range(0.0, 1.0, 0.05) var shield_share: float = 0.3
@export var duration: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(RupturedStatus.new(self))


class RupturedStatus extends Status:
	var passive: ByteRupturedPassive
	var _shield: ShieldStatus = null   # the shield it keeps topping up

	func _init(p_passive: ByteRupturedPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_healed(unit: BattleUnit, gained: float) -> void:
		var amount := gained * passive.shield_share
		if amount <= 0.0:
			return
		if _shield != null and unit.statuses.has(_shield) and _shield.shield > 0.0:
			_shield.shield += amount   # the same shield grows and starts its timer over
			_shield.time_left = passive.duration
			unit.get_tree().call_group("damage_tracker", "record_shielding", unit.get_instance_id(), amount)
			return
		_shield = null
		var before := unit.statuses.duplicate()
		unit.add_shield(amount, passive.duration, unit.get_instance_id())
		for status in unit.statuses:
			if status is ShieldStatus and not before.has(status):
				_shield = status   # the one just made
