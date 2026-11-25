class_name StartingShieldEffect
extends Passive
## Starts combat with a shield.
## Prepared's Might Ward Empower: when that shield breaks, enemies within Break Radius are
## stunned for Break Stun seconds.

@export var amount: float = 400.0
## Seconds it lasts. 0 = for the rest of combat.
@export var duration: float = 0.0
@export var break_stun: float = 0.0
@export var break_radius: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	var before := unit.statuses.duplicate()
	unit.add_shield(amount, duration if duration > 0.0 else INF, unit.get_instance_id())
	if break_stun <= 0.0:
		return
	for status in unit.statuses:
		if not before.has(status) and status is ShieldStatus:
			unit.add_status(BreakWatch.new(self, status))
			return


class BreakWatch extends Status:
	var effect: StartingShieldEffect
	var shield: Status

	func _init(p_effect: StartingShieldEffect, p_shield: Status) -> void:
		effect = p_effect
		shield = p_shield

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func tick(unit: BattleUnit, _delta: float) -> void:
		if unit.statuses.has(shield) or not unit.alive or unit.grid == null:
			return
		unit.remove_status(self)   # broken: stun the enemies next to it, once
		KeepsakeVfx.missile_blast(unit.get_parent(), unit.global_position, 40.0, KeepsakeVfx.SHIELD_WRACK_COLOR)
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy != null and enemy.alive and enemy.team != unit.team \
					and unit.grid.get_distance(unit.cell, enemy.cell) <= effect.break_radius:
				enemy.stun(effect.break_stun, unit)
