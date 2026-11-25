class_name ByteRegenPassive
extends Passive
## Byte A2: Regeneration is higher by Regen (health per second).

@export var regen: float = 10.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(RegenStatus.new(self))


class RegenStatus extends Status:
	var passive: ByteRegenPassive

	func _init(p_passive: ByteRegenPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_health_regen(_unit: BattleUnit, value: float) -> float:
		return value + passive.regen
