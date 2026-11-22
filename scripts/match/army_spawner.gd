class_name ArmySpawner
extends RefCounted
## Turns saved armies (ArmyUnits) into BattleUnits on a grid, and reads what's left after
## a battle. Used by the match screen and by the computer opponent's simulations.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn


## Spawns every placed unit of `army` for `team`. `mirrored` puts it on the far side, the
## way the other player's army is shown. Each BattleUnit remembers its ArmyUnit's index
## in `army` as the "army_index" meta. Every unit gets the army's `ascensions` (its
## army-wide ones; a chosen-unit one goes only to the unit it was given to).
static func spawn(army: Array[ArmyUnit], team: int, mirrored: bool, parent: Node, ascensions: Array[Ascension] = []) -> Array[BattleUnit]:
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
		unit.ascensions.assign(ascensions.filter(func(a): return not a.is_chosen()) + entry.ascensions)
		unit.match_stats = entry.match_stats.duplicate()
		unit.glory = entry.glory
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


## What this fight added to each army's rest-of-match gains (Codger B): {team: {army
## index: {"stats": {Stats.Stat: amount}, "glory": stacks}}}. Only units that gained some.
static func collect_match_gains(tree: SceneTree) -> Dictionary:
	var gains := {}
	if not _reserve_earned.is_empty():
		gains["reserve"] = _reserve_earned.duplicate()   # {team: Reserve earned this fight}
		_reserve_earned.clear()
	if not _shards_earned.is_empty():
		gains["shards"] = _shards_earned.duplicate(true)   # {team: [Shard.Kind, ...]} earned this fight
		_shards_earned.clear()
	for entry in _fallen:   # units that died this fight: what they'd earned still counts
		if not gains.has(entry["team"]):
			gains[entry["team"]] = {}
		gains[entry["team"]][entry["index"]] = {"stats": entry["stats"], "glory": entry["glory"]}
	_fallen.clear()
	for node in tree.get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit.is_summon or not unit.has_meta("army_index"):
			continue
		if unit.match_gains.is_empty() and unit.glory_gained == 0:
			continue
		if not gains.has(unit.team):
			gains[unit.team] = {}
		gains[unit.team][unit.get_meta("army_index")] = {"stats": unit.match_gains.duplicate(), "glory": unit.glory_gained}
	return gains


## Gains of army units that died during the current fight (see bank_fallen).
static var _fallen: Array = []


## A unit is dying: keeps what it earned this fight for the rest of the match (Glory,
## permanent stats), so dying later in the fight doesn't lose it.
static func bank_fallen(unit: BattleUnit) -> void:
	if unit.is_summon or not unit.has_meta("army_index"):
		return
	if unit.match_gains.is_empty() and unit.glory_gained == 0:
		return
	_fallen.append({"team": unit.team, "index": unit.get_meta("army_index"),
			"stats": unit.match_gains.duplicate(), "glory": unit.glory_gained})


## A new fight: forget the last one's fallen (test battles never collect theirs).
static func reset_fallen() -> void:
	_fallen.clear()
	_reserve_earned.clear()
	_shards_earned.clear()


## Reserve a team's player earns during the current fight (Von Carrow's hero Ascension),
## paid out after the combat by whatever collects its gains. Test battles never collect, so
## they never pay.
static var _reserve_earned := {}


static func earn_reserve(team: int, amount: int) -> void:
	_reserve_earned[team] = _reserve_earned.get(team, 0) + amount


## Reserve `team` earned in a fight, from collect_match_gains' result.
static func reserve_from(gains: Dictionary, team: int) -> int:
	return int(gains.get("reserve", {}).get(team, 0))


## Shards a team's units earned this fight (SHRED A2), paid into its inventory afterwards.
## Like Reserve, only real combats pay: the computer's test battles never collect them.
static var _shards_earned := {}

static func earn_shard(team: int, kind: Shard.Kind) -> void:
	if not _shards_earned.has(team):
		_shards_earned[team] = []
	_shards_earned[team].append(kind)


## The Shard items `team` earned in a fight, from collect_match_gains' result.
static func shards_from(gains: Dictionary, team: int) -> Array[Keepsake]:
	var result: Array[Keepsake] = []
	for kind in gains.get("shards", {}).get(team, []):
		var shard := load(SHARD_DIR + SHARD_FILES[kind] + ".tres") as Keepsake
		if shard != null:
			result.append(shard)
	return result

const SHARD_DIR := "res://data/keepsakes/shards/"
const SHARD_FILES := {
	Shard.Kind.MIGHT: "might", Shard.Kind.MIGHT_WARD: "might_ward",
	Shard.Kind.CELERITY: "celerity", Shard.Kind.CELERITY_WARD: "celerity_ward",
	Shard.Kind.INSIGHT: "insight", Shard.Kind.INSIGHT_WARD: "insight_ward",
	Shard.Kind.HEALTH: "health", Shard.Kind.WRACK: "wrack",
}


## Adds one team's gains (from collect_match_gains) to the army they were spawned from.
static func apply_match_gains(army: Array[ArmyUnit], team_gains: Dictionary) -> void:
	for index in team_gains:
		if index < 0 or index >= army.size():
			continue
		var entry := army[index]
		var stats: Dictionary = team_gains[index]["stats"]
		for stat in stats:
			entry.match_stats[stat] = entry.match_stats.get(stat, 0.0) + stats[stat]
		entry.glory += int(team_gains[index]["glory"])
