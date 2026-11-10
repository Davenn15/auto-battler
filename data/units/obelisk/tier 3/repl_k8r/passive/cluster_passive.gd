class_name ClusterPassive
extends Passive
## REPL\K8R gains wards for each ally near it (its duplicates count).

## Added to each of its three wards per nearby ally.
@export var wards_per_ally: float = 6.0
## How close an ally must be, in hex cells.
@export var radius_cells: int = 2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ClusterStatus.new(wards_per_ally, radius_cells))


class ClusterStatus extends Status:
	const GLOW_KEY := "VfxReplCluster"
	const RECOUNT := 0.25   # seconds between counts
	var per_ally: float
	var radius: int
	var allies := 0
	var _timer := 0.0

	func _init(p_per_ally: float, p_radius: int) -> void:
		per_ally = p_per_ally
		radius = p_radius

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_removed(unit: BattleUnit) -> void:
		KeepsakeVfx.clear(unit, GLOW_KEY)

	func tick(unit: BattleUnit, delta: float) -> void:
		_timer -= delta
		if _timer > 0.0:
			return
		_timer = RECOUNT
		var count := 0
		for node in unit.get_tree().get_nodes_in_group("units"):
			var other := node as BattleUnit
			if other != null and other != unit and other.alive and other.team == unit.team \
					and unit.grid.get_distance(unit.cell, other.cell) <= radius:
				count += 1
		if count != allies:
			allies = count
			if allies > 0:
				KeepsakeVfx.set_glow(unit, GLOW_KEY, Color(Replicator.COLOR, 0.7), clampf(allies * 0.06, 0.0, 0.35))
			else:
				KeepsakeVfx.clear(unit, GLOW_KEY)

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat == Stats.Stat.MIGHT_WARD or stat == Stats.Stat.INSIGHT_WARD or stat == Stats.Stat.CELERITY_WARD:
			return value + per_ally * allies
		return value
