class_name RecycleStatus
extends Status
## Recycloid's passive (see RecyclePassive). It listens for every unit's death, including
## summons that appear mid-fight.

var range_cells: int
var share: float
## The last of his allies to die (not summons): what it takes to bring back a copy of it.
## {data, path, buffs, items, cell}, or empty.
var last_dead_ally: Dictionary = {}
var _owner: BattleUnit
var _watched := {}   # instance ids of units whose deaths are being listened for


func _init(p_range: int, p_share: float) -> void:
	range_cells = p_range
	share = p_share


func on_applied(unit: BattleUnit) -> void:
	_owner = unit


func tick(unit: BattleUnit, _delta: float) -> void:
	# Start listening to any unit not listened to yet (summons can appear at any time).
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other != null and other != unit and not _watched.has(other.get_instance_id()):
			_watched[other.get_instance_id()] = true
			other.died.connect(_on_death)


func _on_death(dead: BattleUnit) -> void:
	var me := _owner
	if not is_instance_valid(me) or not me.alive or not me.active:
		return
	if dead.team == me.team and not dead.is_summon:
		last_dead_ally = {"data": dead.data, "path": dead.upgrade_path.duplicate(), "buffs": dead.buffs,
				"items": dead.keepsakes.duplicate(), "cell": dead.cell}
	if me.grid.get_distance(me.cell, dead.cell) > range_cells:
		return
	var ally := _pick_ally(me)
	if ally == null:
		return
	var amount := dead.max_health * share
	KeepsakeVfx.recycle_orb(dead.global_position, ally)
	ally.heal(amount, me.get_instance_id())


## The most hurt ally near him (by share of health), or a random nearby one if all are full.
func _pick_ally(me: BattleUnit) -> BattleUnit:
	var nearby: Array[BattleUnit] = []
	for node in me.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team == me.team \
				and me.grid.get_distance(me.cell, unit.cell) <= range_cells:
			nearby.append(unit)
	if nearby.is_empty():
		return null
	var hurt := nearby.filter(func(u): return u.health < u.max_health)
	if hurt.is_empty():
		return CombatRng.pick(nearby)
	hurt.sort_custom(func(a, b): return a.health / a.max_health < b.health / b.max_health)
	return hurt[0]
