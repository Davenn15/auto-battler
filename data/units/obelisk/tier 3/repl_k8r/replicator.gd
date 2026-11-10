class_name Replicator
extends RefCounted
## Shared helpers for REPL\K8R: telling REPL\K8Rs apart and making duplicates of one.
## Duplicates are full units (upgrades, Gambit, the items they're given) that count as
## summons: they don't count toward surviving Aura, and their damage is credited to the
## REPL\K8R that started it all.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn
const COLOR := Color(0.05, 0.62, 0.45)       # deep phthalo green
const LIGHT := Color(0.35, 0.95, 0.72)       # the same green, bright enough for text
## Meta key on duplicates: the original's full max health, which seeds scale from.
const FULL_HEALTH_META := "repl_full_health"


## True for REPL\K8R and its duplicates (they all carry its passive).
static func is_replk8r(unit: BattleUnit) -> bool:
	if unit == null:
		return false
	for passive in unit.passives:
		if passive is ClusterPassive:
			return true
	return false


## Everything needed to make a duplicate of `unit`, even after it has died.
static func template(unit: BattleUnit) -> Dictionary:
	return {
		"data": unit.data,
		"path": unit.upgrade_path.duplicate(),
		"buffs": unit.buffs,
		"team": unit.team,
		"credit": unit.get_credit_id(),
		"parent": unit.get_parent(),
		"full_health": unit.get_meta(FULL_HEALTH_META, unit.max_health),
	}


## Makes a duplicate from `tmpl` at `cell`, holding `items`, with `max_hp` max health and
## `hp` health. Starts with no Charge. Returns null if the battle isn't on any more.
static func spawn(tmpl: Dictionary, cell: Vector2i, items: Array, max_hp: float, hp: float) -> BattleUnit:
	var parent: Node = tmpl["parent"]
	if not is_instance_valid(parent):
		return null
	var copy := UNIT_SCENE.instantiate() as BattleUnit
	copy.data = tmpl["data"]
	copy.team = tmpl["team"]
	copy.upgrade_path.assign(tmpl["path"])
	copy.buffs = tmpl["buffs"]
	copy.auto_place = false
	parent.add_child(copy)   # _ready builds it from its data
	for item in items:
		copy.equip(item)
	copy.place_at(cell)
	# Built as a normal unit (so it keeps its stats and Gambit), then made a summon.
	copy.is_summon = true
	copy._summoner_id = tmpl["credit"]
	copy.set_meta(FULL_HEALTH_META, tmpl["full_health"])
	copy.get_tree().call_group("battle_manager", "add_summon", copy)
	if not is_instance_valid(copy) or copy.is_queued_for_deletion():
		return null
	# After add_summon: start_combat resets health bars and Charge.
	copy.resize_health(max_hp, hp)
	copy.charge = 0.0
	copy._update_charge_bar()
	KeepsakeVfx.missile_blast(parent, copy.global_position, 34.0, COLOR)
	return copy


## Up to `count` free cells near `center`, nearest first (looks further out if it must).
static func free_cells_near(grid: BattleGrid, center: Vector2i, count: int) -> Array[Vector2i]:
	for reach in [1, 2, 3]:
		var cells := grid.free_cells_in_range(center, reach)
		if cells.size() >= count or reach == 3:
			cells.sort_custom(func(a, b): return grid.get_distance(center, a) < grid.get_distance(center, b))
			return cells.slice(0, count)
	return []
