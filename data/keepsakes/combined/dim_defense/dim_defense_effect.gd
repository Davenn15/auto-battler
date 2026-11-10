class_name DimDefenseEffect
extends Passive
## Enemies near the unit gain less charge.

@export_range(0.0, 1.0, 0.05) var reduction: float = 0.25
@export var radius_cells: int = 2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Dimmer.new(self))


## On the wearer: keeps every nearby enemy dimmed.
class Dimmer extends Status:
	var effect: DimDefenseEffect

	func _init(p_effect: DimDefenseEffect) -> void:
		effect = p_effect

	func on_applied(unit: BattleUnit) -> void:
		KeepsakeVfx.dim_aura(unit, effect.radius_cells)

	func on_removed(unit: BattleUnit) -> void:
		KeepsakeVfx.clear(unit, "VfxDim")

	func tick(unit: BattleUnit, _delta: float) -> void:
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy == null or not enemy.alive or enemy.team == unit.team \
					or unit.grid.get_distance(unit.cell, enemy.cell) > effect.radius_cells:
				continue
			var dimmed: Dimmed = null
			for status in enemy.statuses:
				if status is Dimmed and status.source_id == unit.get_instance_id():
					dimmed = status
			if dimmed == null:
				enemy.add_status(Dimmed.new(unit.get_instance_id(), effect.reduction))
			else:
				dimmed.time_left = Dimmed.LINGER


## On an enemy: gains less charge. Wears off shortly after it leaves the aura.
class Dimmed extends Status:
	const LINGER := 0.25
	var source_id: int
	var reduction: float
	var time_left := LINGER

	func _init(p_source_id: int, p_reduction: float) -> void:
		source_id = p_source_id
		reduction = p_reduction

	func modify_charge_gain(_unit: BattleUnit, amount: float) -> float:
		return amount * (1.0 - reduction)

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			unit.remove_status(self)
