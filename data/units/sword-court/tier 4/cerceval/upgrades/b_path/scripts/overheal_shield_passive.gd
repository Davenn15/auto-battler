class_name OverhealShieldPassive
extends Passive
## Cerceval B: healing he receives past his max health becomes Shield, up to Cap Share of
## his max health. The Shield lasts until it's used up.

@export_range(0.0, 2.0, 0.05) var cap_share: float = 0.3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(OverhealStatus.new(self))


class OverhealStatus extends Status:
	var passive: OverhealShieldPassive
	var _shield: OverhealShield = null

	func _init(p_passive: OverhealShieldPassive) -> void:
		passive = p_passive

	func on_overheal(unit: BattleUnit, excess: float) -> void:
		var cap := unit.max_health * passive.cap_share
		if _shield == null or not unit.statuses.has(_shield):
			_shield = OverhealShield.new(0.0, INF)
			unit.add_status(_shield)
		var added := minf(excess, maxf(cap - _shield.shield, 0.0))
		if added <= 0.0:
			return
		_shield.shield += added
		unit.get_tree().call_group("damage_tracker", "record_shielding", unit.get_instance_id(), added)


## The Shield itself: like any shield, but it goes away once it's used up.
class OverhealShield extends ShieldStatus:
	func tick(unit: BattleUnit, delta: float) -> void:
		if shield <= 0.0:
			unit.remove_status(self)
			return
		super.tick(unit, delta)
