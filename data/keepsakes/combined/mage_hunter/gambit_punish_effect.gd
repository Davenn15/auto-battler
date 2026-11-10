class_name GambitPunishEffect
extends Passive
## Whenever an enemy within range starts its Gambit, the unit attacks it.

@export var range_cells: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Vigil.new(range_cells))


class Vigil extends Status:
	var range_cells: int
	var _unit: BattleUnit
	var _watching: Array[BattleUnit] = []

	func _init(p_range: int) -> void:
		range_cells = p_range

	func on_applied(unit: BattleUnit) -> void:
		_unit = unit
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy != null and enemy.team != unit.team:
				enemy.gambit_cast.connect(_on_enemy_cast)
				_watching.append(enemy)

	func on_removed(_u: BattleUnit) -> void:
		for enemy in _watching:
			if is_instance_valid(enemy) and enemy.gambit_cast.is_connected(_on_enemy_cast):
				enemy.gambit_cast.disconnect(_on_enemy_cast)
		_watching.clear()

	func _on_enemy_cast(enemy: BattleUnit) -> void:
		if is_instance_valid(_unit) and _unit.alive and _unit.active \
				and _unit.grid.get_distance(_unit.cell, enemy.cell) <= range_cells:
			# A blue sword swing in place of the usual white one.
			_unit.hide_next_swing = KeepsakeVfx.enabled()
			_unit.bonus_attack(enemy)
			_unit.hide_next_swing = false
			if KeepsakeVfx.enabled():
				KeepsakeVfx.swing(_unit, (enemy.global_position - _unit.global_position).angle(), Color(0.3, 0.55, 1.0))
