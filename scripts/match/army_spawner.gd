class_name ArmySpawner
extends RefCounted
## Turns saved armies (ArmyUnits) into BattleUnits on a grid, and reads what's left after
## a battle. Used by the match screen and by the computer opponent's simulations.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn


## Spawns every placed unit of `army` for `team`. `mirrored` puts it on the far side, the
## way the other player's army is shown. Each BattleUnit remembers its ArmyUnit's index
## in `army` as the "army_index" meta.
static func spawn(army: Array[ArmyUnit], team: int, mirrored: bool, parent: Node) -> Array[BattleUnit]:
	var spawned: Array[BattleUnit] = []
	for i in army.size():
		var entry := army[i]
		if not entry.placed:
			continue
		var unit := UNIT_SCENE.instantiate() as BattleUnit
		unit.data = entry.data
		unit.team = team
		unit.upgrade_path.assign(entry.path)
		unit.buffs = entry.buffs
		unit.auto_place = false
		unit.set_meta("army_index", i)
		parent.add_child(unit)
		for item in entry.items:   # after add_child: equip recomputes health from the data
			unit.equip(item)
		unit.place_at(MatchRules.mirror_cell(entry.cell) if mirrored else entry.cell)
		spawned.append(unit)
	return spawned


## Aura worth of `team`'s units still standing. Summons don't count, and neither do items.
static func surviving_aura(tree: SceneTree, team: int) -> int:
	var total := 0
	for node in tree.get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team == team and not unit.is_summon:
			total += unit.get_aura_value()
	return total
