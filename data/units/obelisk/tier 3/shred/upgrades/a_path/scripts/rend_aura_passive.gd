class_name ShredRendAuraPassive
extends Passive
## SHRED A1: enemies within Radius cells of SHRED receive Cut less healing and Shield. An
## aura, so 100 Immovability blocks it (BattleUnit.debuff_strength).

@export_range(0.0, 1.0, 0.05) var cut: float = 0.3
@export var radius: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(AuraStatus.new(self))


## On SHRED: hands the debuff to enemies that come within reach.
class AuraStatus extends Status:
	var passive: ShredRendAuraPassive

	func _init(p_passive: ShredRendAuraPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func tick(unit: BattleUnit, _delta: float) -> void:
		if not unit.active:
			return
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy == null or not enemy.alive or enemy.team == unit.team:
				continue
			if unit.grid.get_distance(unit.cell, enemy.cell) > passive.radius:
				continue
			var has := false
			for status in enemy.statuses:
				if status is RendStatus and status.source == unit:
					has = true
					break
			if not has:
				enemy.add_status(RendStatus.new(passive, unit))


## On an enemy near SHRED: less healing and Shield. It ends itself once the enemy is out of
## reach, or SHRED is gone.
class RendStatus extends Status:
	var passive: ShredRendAuraPassive
	var source   # untyped: may be freed

	func _init(p_passive: ShredRendAuraPassive, p_source: BattleUnit) -> void:
		passive = p_passive
		source = p_source

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func _active(unit: BattleUnit) -> bool:
		return is_instance_valid(source) and source.alive \
				and unit.grid.get_distance(unit.cell, source.cell) <= passive.radius

	func _factor(unit: BattleUnit) -> float:
		return 1.0 - passive.cut * unit.debuff_strength()

	func modify_healing_received(unit: BattleUnit, amount: float) -> float:
		return amount * _factor(unit) if _active(unit) else amount

	func modify_shield_received(unit: BattleUnit, amount: float) -> float:
		return amount * _factor(unit) if _active(unit) else amount

	func tick(unit: BattleUnit, _delta: float) -> void:
		if not _active(unit):
			unit.remove_status(self)
