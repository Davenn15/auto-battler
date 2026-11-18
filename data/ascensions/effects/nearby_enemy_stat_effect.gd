class_name NearbyEnemyStatEffect
extends Passive
## An Ascension effect (Immovable): enemies within Radius Cells of the unit have Amount less
## of Stat while they stay that close. Rechecked a few times a second; wears off a moment
## after they leave. Weaker on enemies that resist debuffs.

@export var stat: Stats.Stat = Stats.Stat.CELERITY
## Taken off the stat (20 = -20).
@export var amount: float = 20.0
@export var radius_cells: int = 2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(AuraSource.new(self))


## On the unit: finds the enemies in range and refreshes their debuff.
class AuraSource extends Status:
	const RECHECK := 0.2
	var effect: NearbyEnemyStatEffect
	var _timer := 0.0

	func _init(p_effect: NearbyEnemyStatEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active or not unit.alive:
			return
		_timer -= delta
		if _timer > 0.0:
			return
		_timer = RECHECK
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy != null and enemy.alive and enemy.team != unit.team \
					and unit.grid.get_distance(unit.cell, enemy.cell) <= effect.radius_cells:
				AuraDebuff.refresh_on(enemy, unit.get_instance_id(), effect)


## On an enemy near the source: the stat cut, gone a moment after its last refresh.
## One per source, so two sources stack.
class AuraDebuff extends Status:
	const LINGER := 0.3
	var source_id: int
	var effect: NearbyEnemyStatEffect
	var _left := LINGER
	var _strength := 1.0

	static func refresh_on(enemy: BattleUnit, p_source_id: int, p_effect: NearbyEnemyStatEffect) -> void:
		for status in enemy.statuses:
			if status is AuraDebuff and status.source_id == p_source_id:
				status._left = LINGER
				return
		var debuff := AuraDebuff.new()
		debuff.source_id = p_source_id
		debuff.effect = p_effect
		enemy.add_status(debuff)

	func on_applied(unit: BattleUnit) -> void:
		_strength = unit.debuff_strength()

	func tick(unit: BattleUnit, delta: float) -> void:
		_left -= delta
		if _left <= 0.0:
			unit.remove_status(self)

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat == effect.stat:
			return value - effect.amount * _strength
		return value
