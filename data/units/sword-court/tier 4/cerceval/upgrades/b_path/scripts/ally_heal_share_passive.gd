class_name AllyHealSharePassive
extends Passive
## Cerceval B1: whenever an ally within Radius Cells is healed, he's healed for Share of it
## too (which can overflow into his B Shield). Healing passed on this way isn't passed on
## again.

@export_range(0.0, 2.0, 0.05) var share: float = 0.4
@export var radius_cells: int = 2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(AllyHealShareStatus.new(self))


class AllyHealShareStatus extends Status:
	var passive: AllyHealSharePassive

	func _init(p_passive: AllyHealSharePassive) -> void:
		passive = p_passive

	func on_applied(unit: BattleUnit) -> void:
		BattleUnit.listen_for_ally_heals(unit, true)

	func on_removed(unit: BattleUnit) -> void:
		BattleUnit.listen_for_ally_heals(unit, false)

	func on_ally_healed(unit: BattleUnit, ally: BattleUnit, amount: float) -> void:
		if unit.active and unit.grid.get_distance(unit.cell, ally.cell) <= passive.radius_cells:
			unit.heal(amount * passive.share, unit.get_instance_id(), false)
