class_name RowdyVigorPassive
extends Passive
## Brogaine B2: Health Share more max health, and Regen Share more Regeneration from all
## sources.

@export_range(0.0, 1.0, 0.05) var health_share: float = 0.25
@export_range(0.0, 1.0, 0.05) var regen_share: float = 0.25


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(VigorStatus.new(self))


class VigorStatus extends Status:
	var passive: RowdyVigorPassive
	var _granted := 0.0

	func _init(p_passive: RowdyVigorPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	## The extra health comes off again when the status does (each combat starts afresh).
	func on_applied(unit: BattleUnit) -> void:
		_granted = unit.max_health * passive.health_share
		_resize(unit, _granted)

	func on_removed(unit: BattleUnit) -> void:
		_resize(unit, -_granted)
		_granted = 0.0

	## Like Immovability's health: gaining heals by the same amount, losing only trims
	## health to the new max.
	func _resize(unit: BattleUnit, change: float) -> void:
		unit.max_health = maxf(unit.max_health + change, 1.0)
		unit.health = minf(unit.health + maxf(change, 0.0), unit.max_health)
		if unit.health_bar != null:
			unit.health_bar.max_value = unit.max_health
		unit._update_health_bar()
		unit._update_health_ticks()

	func modify_final_health_regen(_unit: BattleUnit, regen: float) -> float:
		return regen * (1.0 + passive.regen_share)
