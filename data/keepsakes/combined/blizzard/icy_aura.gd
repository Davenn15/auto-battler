class_name IcyAuraEffect
extends Passive
## Deals damage to every nearby enemy once a second.

@export var damage: float = 30.0
@export var radius_cells: int = 2
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Chill.new(self))


class Chill extends Status:
	var effect: IcyAuraEffect
	var _timer := 1.0

	func _init(p_effect: IcyAuraEffect) -> void:
		effect = p_effect

	func on_applied(unit: BattleUnit) -> void:
		KeepsakeVfx.snow_ring(unit, effect.radius_cells)

	func on_removed(unit: BattleUnit) -> void:
		KeepsakeVfx.clear(unit, "VfxSnow")

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active:
			return
		_timer -= delta
		if _timer > 0.0:
			return
		_timer += 1.0
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy != null and enemy.alive and enemy.team != unit.team \
					and unit.grid.get_distance(unit.cell, enemy.cell) <= effect.radius_cells:
				var dealt := enemy.take_damage(effect.damage, 0, effect.damage_type, false, null, false)
				enemy.add_running_damage("icy_%d" % unit.get_instance_id(), dealt, Stats.damage_color(effect.damage_type), 0, 1.25)
				unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_instance_id(), dealt)
