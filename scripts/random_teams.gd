class_name RandomTeams
extends RefCounted
## Builds random teams worth an exact ARV and places them like a player would. Shared by
## the random battle scene and the balance simulator, so both make teams the same way.
## Uses Godot's global random numbers: call seed() first to get the same teams again.

const MAX_ATTEMPTS := 200
const PLACEMENT_PASSES := 10   # most rounds of units moving to better starting cells
## Placement score lost per enemy that would reach a ranged unit before its front line.
## Bigger than any range score, so staying covered always comes first.
const EXPOSED_PENALTY := 5000


## Every UnitData under `dir` and its subfolders, skipping files that start with "dummy"
## and profiles marked summon_only (things units create, like Sumpton's bag).
static func load_roster(dir: String) -> Array[UnitData]:
	var roster: Array[UnitData] = []
	for listed in DirAccess.get_files_at(dir):
		var file := listed.trim_suffix(".remap")   # exported builds list "x.tres.remap"
		if file.ends_with(".tres") and not file.begins_with("dummy"):
			var data := load(dir.path_join(file)) as UnitData
			if data != null and data.get("summon_only") != true:
				roster.append(data)
	for sub in DirAccess.get_directories_at(dir):
		roster.append_array(load_roster(dir.path_join(sub)))
	return roster


## Every upgrade path a unit can have, grouped by level: [[[]], [[0], [1]], [[0, 0], ...]].
## Units without an upgrade tree only have level 0.
static func paths_by_level(data: UnitData) -> Array:
	var levels: Array = [[[]]]
	var level_1: Array = []
	var level_2: Array = []
	for i in data.upgrades.size():
		level_1.append([i])
		for j in data.upgrades[i].next_choices.size():
			level_2.append([i, j])
	if not level_1.is_empty():
		levels.append(level_1)
	if not level_2.is_empty():
		levels.append(level_2)
	return levels


## A random team worth exactly `target` Aura, as a list of {data, path}. Each pick
## chooses a unit first, then a level, then a path, so units with upgrade trees aren't
## picked more often just because they have more options. With `require_frontline`, a
## team needs at least one front-liner (see is_frontline). `forced` picks (from
## parse_pick) always go in first; one whose path is null gets a random affordable path.
## Empty if none was found.
static func make_team(roster: Array[UnitData], target: int, max_team: int = 8, allow_duplicates: bool = false,
		require_frontline: bool = false, second_row: Array[String] = [], forced: Array = []) -> Array:
	for attempt in MAX_ATTEMPTS:
		var team: Array = []
		var remaining := target
		for wanted in forced:
			var data: UnitData = wanted["data"]
			var path = wanted["path"]
			if path == null:
				path = _random_path(data, remaining)
			team.append({"data": data, "path": path})
			remaining -= Economy.unit_aura_value(data.tier, path.size())
		if remaining < 0 or team.size() > max_team:
			continue
		while remaining > 0 and team.size() < max_team:
			var affordable: Array[UnitData] = []
			for data in roster:
				if not allow_duplicates and team.any(func(pick): return pick["data"] == data):
					continue
				if Economy.unit_aura_value(data.tier, 0) <= remaining:
					affordable.append(data)
			if affordable.is_empty():
				break
			var data: UnitData = affordable.pick_random()
			var path := _random_path(data, remaining)
			team.append({"data": data, "path": path})
			remaining -= Economy.unit_aura_value(data.tier, path.size())
		if remaining != 0:
			continue
		if require_frontline and not team.any(func(pick): return is_frontline(pick, second_row)):
			continue   # all back line: roll again
		return team
	return []


## A random level the unit can afford with `budget` Aura (at least level 0), then a
## random path at that level.
static func _random_path(data: UnitData, budget: int) -> Array:
	var levels := paths_by_level(data)
	var max_level := 0
	for level in levels.size():
		if Economy.unit_aura_value(data.tier, level) <= budget:
			max_level = level
	return levels[randi_range(0, max_level)].pick_random()


## Turns text like "merribold b", "garth a1", "silt base" or just "wesper" into a forced
## pick for make_team: {data, path}, where path is null for a random path. Returns
## {"error": message} if the unit or path doesn't exist. Names ignore case.
static func parse_pick(roster: Array[UnitData], text: String) -> Dictionary:
	var words := text.strip_edges().to_lower().split(" ", false)
	if words.is_empty():
		return {"error": "empty entry"}
	var whole := " ".join(words)
	for data in roster:
		if data.display_name.to_lower() == whole:
			return {"data": data, "path": null}   # no path given
	if words.size() == 1:
		return {"error": "no unit called \"%s\"" % whole}
	var label := words[words.size() - 1]
	words.remove_at(words.size() - 1)
	var name := " ".join(words)
	for data in roster:
		if data.display_name.to_lower() != name:
			continue
		for level in paths_by_level(data):
			for path in level:
				if path_label(path).to_lower() == label:
					return {"data": data, "path": path}
		return {"error": "%s has no path \"%s\"" % [data.display_name, label]}
	return {"error": "no unit called \"%s\"" % name}


## The least Aura a list of forced picks can cost: random paths count as level 0.
static func min_cost(forced: Array) -> int:
	var total := 0
	for wanted in forced:
		var level: int = 0 if wanted["path"] == null else wanted["path"].size()
		total += Economy.unit_aura_value(wanted["data"].tier, level)
	return total


## True for a melee pick that isn't listed in `second_row`: the units that stand in front
## and take the first hits.
static func is_frontline(pick: Dictionary, second_row: Array[String] = []) -> bool:
	return attack_range(pick) <= 1 and not second_row.has(pick["data"].display_name.to_lower())


## A pick's attack range: the unit's own plus every chosen upgrade's bonus, the same
## sum BattleUnit._apply_data makes. Needed before the unit exists, for placement.
static func attack_range(pick: Dictionary) -> int:
	var data: UnitData = pick["data"]
	var reach := data.attack_range_cells
	var choices := data.upgrades
	for choice in pick["path"]:
		var upgrade: Upgrade = choices[choice]
		reach += upgrade.attack_range_bonus
		choices = upgrade.next_choices
	return reach


## Where every unit starts, as {team: cells in the same order as that team's picks}.
## Each team stays in its own half. Each unit stands as far from the nearest enemy as it
## can while that enemy is still in its attack range; a unit that can't reach any enemy
## from its half stands as close as it can instead. Units take turns moving to their
## best cell until nobody wants to move.
## Units named in `second_row` (lower-case display names) always start one row behind the
## front, preferably right behind a teammate in the front row.
## Ranged units first make sure every enemy has a front-liner of theirs strictly closer
## than they are, so the enemy's nearest-target pick lands on the front line first. Only
## then do they look for the best range.
static func place_teams(grid: BattleGrid, teams: Dictionary, second_row: Array[String] = []) -> Dictionary:
	var placement := {}
	for team in teams:
		var half := half_cells(grid, team)
		half.shuffle()
		placement[team] = half.slice(0, teams[team].size())   # random start, fixed below

	var movers: Array = []   # [team, index] for every unit
	for team in teams:
		for i in teams[team].size():
			movers.append([team, i])
	for pass_count in PLACEMENT_PASSES:
		var moved := false
		movers.shuffle()
		for mover in movers:
			var team: int = mover[0]
			var i: int = mover[1]
			var cells: Array = placement[team]
			var enemies: Array = placement[3 - team]
			var reach := attack_range(teams[team][i])
			var in_second_row := second_row.has(teams[team][i]["data"].display_name.to_lower())
			var hides_behind_front := reach > 1 and not in_second_row
			var fronts: Array = []   # cells of this team's front-liners, for ranged units to stay behind
			if hides_behind_front:
				for j in teams[team].size():
					if j != i and is_frontline(teams[team][j], second_row):
						fronts.append(cells[j])
			var score_of := func(cell: Vector2i) -> int:
				if in_second_row:
					return _second_row_score(grid, team, cell, cells, i)
				var score := _placement_score(grid, cell, enemies, reach)
				if hides_behind_front and not fronts.is_empty():
					score -= EXPOSED_PENALTY * _exposed_to(grid, cell, enemies, fronts)
				return score
			var best_cells: Array[Vector2i] = []
			var best_score: int = score_of.call(cells[i])
			for cell in half_cells(grid, team):
				if cells.has(cell):
					continue   # a teammate (or this unit) is already there
				var score: int = score_of.call(cell)
				if score > best_score:
					best_score = score
					best_cells = [cell]
				elif score == best_score and not best_cells.is_empty():
					best_cells.append(cell)
			if not best_cells.is_empty():   # only move to a strictly better cell, so it settles
				cells[i] = best_cells.pick_random()
				moved = true
		if not moved:
			break
	return placement


## Every cell in a team's half of the grid: team 2 gets the top rows, team 1 the bottom.
static func half_cells(grid: BattleGrid, team: int) -> Array[Vector2i]:
	var half_rows := grid.rows / 2
	var first_row := half_rows if team == 1 else 0
	var cells: Array[Vector2i] = []
	for r in range(first_row, first_row + half_rows):
		var q_start := -floori(r / 2.0)   # same layout as BattleGrid._ensure_built
		for i in grid.columns:
			cells.append(Vector2i(q_start + i, r))
	return cells


## "base", "A", "B", "A1", "B2", ...: the first choice as a letter, the second as a number.
static func path_label(path: Array) -> String:
	if path.is_empty():
		return "base"
	var label := String.chr(65 + path[0])
	if path.size() > 1:
		label += str(path[1] + 1)
	return label


## How good `cell` is for a unit with attack range `reach`. Any cell with an enemy in
## range beats every cell without one; among those, farther from the nearest enemy is
## better. Without an enemy in range, closer is better.
static func _placement_score(grid: BattleGrid, cell: Vector2i, enemies: Array, reach: int) -> int:
	var nearest := 1000
	for enemy in enemies:
		nearest = mini(nearest, grid.get_distance(cell, enemy))
	return nearest if nearest <= reach else -nearest - 1000


## How many enemies would reach `cell` no later than they reach this team's front line:
## enemies for which no front-liner is strictly closer. Units target the nearest enemy, so
## a ranged unit with 0 here is only picked once the front line is out of the way.
static func _exposed_to(grid: BattleGrid, cell: Vector2i, enemies: Array, fronts: Array) -> int:
	var exposed := 0
	for enemy in enemies:
		var mine := grid.get_distance(cell, enemy)
		var shielded := false
		for front in fronts:
			if grid.get_distance(front, enemy) < mine:
				shielded = true
				break
		if not shielded:
			exposed += 1
	return exposed


## How good `cell` is for a unit that stays out of the front line: only cells in the
## second row count, and each front-row teammate right in front of it adds one.
static func _second_row_score(grid: BattleGrid, team: int, cell: Vector2i, teammates: Array, self_index: int) -> int:
	if cell.y != _row_from_front(grid, team, 1):
		return -1000
	var front := _row_from_front(grid, team, 0)
	var cover := 0
	for j in teammates.size():
		var other: Vector2i = teammates[j]
		if j != self_index and other.y == front and grid.get_distance(cell, other) == 1:
			cover += 1
	return cover


## The row `depth` rows back from a team's front: 0 is the row facing the enemy.
static func _row_from_front(grid: BattleGrid, team: int, depth: int) -> int:
	var half_rows := grid.rows / 2
	return half_rows + depth if team == 1 else half_rows - 1 - depth


# ---------- Keepsakes ----------

## Every Keepsake under `dir` and its subfolders, as {"keepsakes": [...], "shards": [...]}.
## Loose Shards (is_shard) go in "shards", everything else in "keepsakes".
static func load_keepsakes(dir: String) -> Dictionary:
	var pools := {"keepsakes": [], "shards": []}
	_collect_keepsakes(dir, pools)
	return pools


static func _collect_keepsakes(dir: String, pools: Dictionary) -> void:
	for listed in DirAccess.get_files_at(dir):
		var file := listed.trim_suffix(".remap")   # exported builds list "x.tres.remap"
		if not file.ends_with(".tres"):
			continue
		var keepsake := load(dir.path_join(file)) as Keepsake   # skips the _effect.tres files
		if keepsake != null:
			pools["shards" if keepsake.is_shard else "keepsakes"].append(keepsake)
	for sub in DirAccess.get_directories_at(dir):
		_collect_keepsakes(dir.path_join(sub), pools)


## A team's Reserve for items: `scale` Reserve per point of ARV (1 = the same as its
## Aura), rounded down to whole Shards.
static func reserve_budget(arv: int, scale: float) -> int:
	if scale <= 0.0:
		return 0
	return floori(arv * scale / Shard.RESERVE_VALUE) * Shard.RESERVE_VALUE


## Spends `budget` Reserve on random items for a team of `unit_count` units, as one list of
## Keepsakes per unit (at most `per_unit` each). Buys whole keepsakes while it can afford
## them and a unit has a free slot, then a Shard with the last 3. Each item goes to a random
## unit with a free slot. Reserve that can't be spent (every slot full) is left over.
static func buy_keepsakes(pools: Dictionary, budget: int, unit_count: int, per_unit: int = 3) -> Array:
	var loadouts: Array = []
	for i in unit_count:
		loadouts.append([])
	var keepsake_cost := Shard.RESERVE_VALUE * 2
	while budget >= Shard.RESERVE_VALUE:
		var open: Array[int] = []
		for i in unit_count:
			if loadouts[i].size() < per_unit:
				open.append(i)
		if open.is_empty():
			break
		var pool: Array = pools["keepsakes"] if budget >= keepsake_cost else pools["shards"]
		if pool.is_empty():
			break
		var item: Keepsake = pool.pick_random()
		loadouts[open.pick_random()].append(item)
		budget -= item.get_reserve_value()
	return loadouts
