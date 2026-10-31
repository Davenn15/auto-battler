class_name RandomTeams
extends RefCounted
## Builds random teams worth an exact ARV and places them like a player would. Shared by
## the random battle scene and the balance simulator, so both make teams the same way.
## Uses Godot's global random numbers: call seed() first to get the same teams again.

const MAX_ATTEMPTS := 200
const PLACEMENT_PASSES := 10   # most rounds of units moving to better starting cells


## Every UnitData under `dir` and its subfolders, skipping files that start with "dummy".
static func load_roster(dir: String) -> Array[UnitData]:
	var roster: Array[UnitData] = []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tres") and not file.begins_with("dummy"):
			var data := load(dir.path_join(file)) as UnitData
			if data != null:
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
## picked more often just because they have more options. Empty if none was found.
static func make_team(roster: Array[UnitData], target: int, max_team: int = 8, allow_duplicates: bool = false) -> Array:
	for attempt in MAX_ATTEMPTS:
		var team: Array = []
		var remaining := target
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
			var levels := paths_by_level(data)
			var max_level := 0
			for level in levels.size():
				if Economy.unit_aura_value(data.tier, level) <= remaining:
					max_level = level
			var chosen_level := randi_range(0, max_level)
			team.append({"data": data, "path": levels[chosen_level].pick_random()})
			remaining -= Economy.unit_aura_value(data.tier, chosen_level)
		if remaining == 0:
			return team
	return []


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
static func place_teams(grid: BattleGrid, teams: Dictionary) -> Dictionary:
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
			var best_cells: Array[Vector2i] = []
			var best_score := _placement_score(grid, cells[i], enemies, reach)
			for cell in half_cells(grid, team):
				if cells.has(cell):
					continue   # a teammate (or this unit) is already there
				var score := _placement_score(grid, cell, enemies, reach)
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
