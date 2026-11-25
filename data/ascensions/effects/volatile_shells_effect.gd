class_name VolatileShellsEffect
extends Passive
## An Ascension effect (Obelisk, Volatile Shells): when a Construct (a summon, copy or
## revived unit) dies, it explodes: enemies within Radius Cells take Health Share of its max
## health as Insight damage and are stunned for Stun seconds.

@export var health_share: float = 0.15
@export var stun: float = 0.5
@export var radius_cells: int = 1

const COLOR := Color(0.55, 0.95, 0.45)


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(VolatileStatus.new(self))


class VolatileStatus extends Status:
	var effect: VolatileShellsEffect

	func _init(p_effect: VolatileShellsEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_death(unit: BattleUnit) -> void:
		if not Revive.is_construct(unit) or not unit.is_inside_tree():
			return
		var damage := unit.max_health * effect.health_share
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy == null or not enemy.alive or enemy.team == unit.team \
					or unit.grid.get_distance(unit.cell, enemy.cell) > effect.radius_cells:
				continue
			var dealt := enemy.take_damage(BattleUnit.damage_bonus(unit, enemy, damage), 0, Stats.DamageType.INSIGHT)
			unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), dealt)
			if enemy.alive:
				enemy.stun(effect.stun, unit)
		KeepsakeVfx.missile_blast(unit.get_parent(), unit.global_position, 30.0 + 40.0 * effect.radius_cells, VolatileShellsEffect.COLOR)
