class_name DodgeShieldPassive
extends Passive
## FRAME A2: whenever it dodges a hit, it gains a Shield worth Share of the damage the hit
## would have dealt (after its Wards), for Duration seconds.

@export_range(0.0, 2.0, 0.05) var share: float = 0.5
@export var duration: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(DodgeShieldStatus.new(self))


class DodgeShieldStatus extends Status:
	var passive: DodgeShieldPassive

	func _init(p_passive: DodgeShieldPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_dodge(unit: BattleUnit) -> void:
		if unit.dodged_damage > 0.0:
			unit.add_shield(unit.dodged_damage * passive.share, passive.duration, unit.get_instance_id())
