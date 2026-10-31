extends Node2D
## Balance simulator. Runs many battles between random teams of equal ARV, then writes
## every battle and every unit's result to CSV files, plus a summary of win rates.
## Testing tool only: nothing in the game uses this.
##
## Run it from the project folder, without the editor (Godot's _console.exe prints progress):
##   Godot_console.exe --headless --fixed-fps 60 --path . res://tools/balance_sim.tscn -- --battles 500 --arv 6:20
##
## Options (all optional):
##   --battles N      how many battles to run (default 200)
##   --arv A or A:B   ARV of each team. A:B picks a random value in that range each battle (default 10)
##   --max-team N     most units on a team (default 8)
##   --time-limit S   seconds of battle time before the battle is called a draw (default 90)
##   --seed N         random seed, to repeat a run exactly (default: random)
##   --out PATH       folder for the results (default res://tools/sim_results)
##
## --fixed-fps 60 makes every frame count as 1/60 of a second however fast it really runs,
## so battles play out exactly as in the game, just much faster.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn
const UNITS_DIR := "res://data/units"
const START_ROWS := 3   # each team starts in its own 3 rows: team 2 at the top, team 1 at the bottom
const MAX_TEAM_ATTEMPTS := 200

var battles: int = 200
var arv_min: int = 10
var arv_max: int = 10
var max_team: int = 8
var time_limit: float = 90.0
var seed_value: int = 0
var out_dir: String = "res://tools/sim_results"

var _roster: Array[UnitData] = []
var _paths: Dictionary = {}       # UnitData -> upgrade paths by level: [[[]], [[0], [1]], [[0, 0], ...]]
var _records: Dictionary = {}     # unit instance id -> that unit's row for the current battle
var _unit_rows: Array[Dictionary] = []
var _battle_rows: Array[Dictionary] = []
var _battle_over: bool = false
var _winner: int = 0              # 0 = draw


func _ready() -> void:
	add_to_group("damage_tracker")   # units report damage, healing, and shielding to this group
	_parse_args()
	seed(seed_value)
	_load_roster(UNITS_DIR)
	if _roster.is_empty():
		push_error("Balance sim: no units found under %s." % UNITS_DIR)
		get_tree().quit(1)
		return
	print("Balance sim: %d battles, ARV %d-%d, %d units in the roster, seed %d" %
			[battles, arv_min, arv_max, _roster.size(), seed_value])
	_run()


func _run() -> void:
	var started := Time.get_ticks_msec()
	for i in battles:
		await _run_battle(i + 1, randi_range(arv_min, arv_max))
		if (i + 1) % 25 == 0:
			print("  %d / %d battles (%.0fs)" % [i + 1, battles, (Time.get_ticks_msec() - started) / 1000.0])
	_clear_arena()
	_write_results()
	await get_tree().process_frame   # let the last battle's nodes finish freeing first
	get_tree().quit()


# ---------- Settings ----------

func _parse_args() -> void:
	seed_value = randi()
	var args := OS.get_cmdline_user_args()   # everything after "--" on the command line
	for i in args.size() - 1:
		var value := args[i + 1]
		match args[i]:
			"--battles":
				battles = value.to_int()
			"--arv":
				var parts := value.split(":")
				arv_min = parts[0].to_int()
				arv_max = parts[1].to_int() if parts.size() > 1 else arv_min
			"--max-team":
				max_team = value.to_int()
			"--time-limit":
				time_limit = value.to_float()
			"--seed":
				seed_value = value.to_int()
			"--out":
				out_dir = value


# ---------- Roster and teams ----------

## Every UnitData under `dir`, skipping the dummy.
func _load_roster(dir: String) -> void:
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".tres") or file.begins_with("dummy"):
			continue
		var data := load(dir.path_join(file)) as UnitData
		if data != null:
			_roster.append(data)
			_paths[data] = _paths_by_level(data)
	for sub in DirAccess.get_directories_at(dir):
		_load_roster(dir.path_join(sub))


## Every upgrade path the unit can have, grouped by level. Units without an upgrade
## tree only have level 0.
func _paths_by_level(data: UnitData) -> Array:
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
func _make_team(target: int) -> Array:
	for attempt in MAX_TEAM_ATTEMPTS:
		var team: Array = []
		var remaining := target
		while remaining > 0 and team.size() < max_team:
			var affordable: Array[UnitData] = []
			for data in _roster:
				if Economy.unit_aura_value(data.tier, 0) <= remaining:
					affordable.append(data)
			if affordable.is_empty():
				break
			var data: UnitData = affordable.pick_random()
			var levels: Array = _paths[data]
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


# ---------- Running a battle ----------

func _run_battle(index: int, target: int) -> void:
	var teams := {1: _make_team(target), 2: _make_team(target)}
	if teams[1].is_empty() or teams[2].is_empty():
		push_warning("Battle %d: couldn't build a team worth exactly %d ARV; skipped." % [index, target])
		return

	_clear_arena()
	var grid := BattleGrid.new()
	grid.show_debug = false
	add_child(grid)
	var manager := BattleManager.new()
	manager.auto_start = false
	add_child(manager)

	_records.clear()
	var lineups := {}
	for team in teams:
		var cells := _start_cells(grid, team)
		cells.shuffle()
		var names: PackedStringArray = []
		for i in teams[team].size():
			var pick: Dictionary = teams[team][i]
			var unit := _spawn(pick, team, cells[i])
			var row := _new_unit_row(index, target, team, unit, pick)
			_records[unit.get_instance_id()] = row
			names.append("%s[%s]" % [row["unit"], row["path"]])
		lineups[team] = " ".join(names)

	await get_tree().physics_frame   # let every unit finish _ready before the fight
	_battle_over = false
	_winner = 0
	manager.battle_ended.connect(_on_battle_ended)
	manager.start_battle()

	var elapsed := 0.0
	while not _battle_over and elapsed < time_limit:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	if not _battle_over:
		for node in get_tree().get_nodes_in_group("units"):
			(node as BattleUnit).stop_combat()

	for row in _records.values():
		row["result"] = "draw" if _winner == 0 else ("win" if row["team"] == _winner else "loss")
		_unit_rows.append(row)
	_battle_rows.append({
		"battle": index, "arv": target, "winner": _winner, "duration": snappedf(elapsed, 0.01),
		"timed_out": not _battle_over, "team_1": lineups[1], "team_2": lineups[2],
	})


func _spawn(pick: Dictionary, team: int, cell: Vector2i) -> BattleUnit:
	var unit := UNIT_SCENE.instantiate() as BattleUnit
	unit.data = pick["data"]
	unit.team = team
	unit.upgrade_path.assign(pick["path"])
	unit.auto_place = false
	add_child(unit)
	unit.place_at(cell)
	unit.died.connect(_on_unit_died)
	return unit


## The cells in a team's starting rows.
func _start_cells(grid: BattleGrid, team: int) -> Array[Vector2i]:
	var first_row := grid.rows - START_ROWS if team == 1 else 0
	var cells: Array[Vector2i] = []
	for r in range(first_row, first_row + START_ROWS):
		var q_start := -floori(r / 2.0)   # same layout as BattleGrid._ensure_built
		for i in grid.columns:
			cells.append(Vector2i(q_start + i, r))
	return cells


## Removes everything from the last battle: grid, manager, units, projectiles, effects.
## remove_child takes them out of their groups immediately, so the next battle's units
## can't find the old grid.
func _clear_arena() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func _on_battle_ended(winning_team: int) -> void:
	_battle_over = true
	_winner = maxi(winning_team, 0)   # -1 (everyone died) counts as a draw


func _on_unit_died(unit: BattleUnit) -> void:
	var row = _records.get(unit.get_instance_id())
	if row != null:
		row["survived"] = false


# ---------- What the units report (same calls the DamageTracker receives) ----------

func record_damage(unit_id: int, amount: float) -> void:
	_add(unit_id, "damage", amount)


func record_healing(unit_id: int, amount: float) -> void:
	_add(unit_id, "healing", amount)


func record_shielding(unit_id: int, amount: float) -> void:
	_add(unit_id, "shielding", amount)


func _add(unit_id: int, key: String, amount: float) -> void:
	var row = _records.get(unit_id)   # summons and units from other battles aren't recorded
	if row != null:
		row[key] += amount


# ---------- Results ----------

func _new_unit_row(index: int, target: int, team: int, unit: BattleUnit, pick: Dictionary) -> Dictionary:
	var data: UnitData = pick["data"]
	return {
		"battle": index, "arv": target, "team": team, "result": "",
		"unit": data.display_name.capitalize(), "tier": data.tier,
		"path": path_label(pick["path"]), "upgrades": _upgrade_names(data, pick["path"]),
		"aura": unit.get_aura_value(), "survived": true,
		"damage": 0.0, "healing": 0.0, "shielding": 0.0,
	}


## "base", "A", "B", "A1", "B2", ...: the first choice as a letter, the second as a number.
static func path_label(path: Array) -> String:
	if path.is_empty():
		return "base"
	var label := String.chr(65 + path[0])
	if path.size() > 1:
		label += str(path[1] + 1)
	return label


## The names of the upgrades on a path, e.g. "Stalwart > A1". Upgrades still using the
## default name show as their path label instead.
func _upgrade_names(data: UnitData, path: Array) -> String:
	var names: PackedStringArray = []
	var choices := data.upgrades
	for level in path.size():
		var upgrade: Upgrade = choices[path[level]]
		var is_default := upgrade.upgrade_name == "Upgrade" or upgrade.upgrade_name.is_empty()
		names.append(path_label(path.slice(0, level + 1)) if is_default else upgrade.upgrade_name)
		choices = upgrade.next_choices
	return " > ".join(names)


func _write_results() -> void:
	var dir := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(dir)
	# Keep results out of Godot's importer and out of git, without touching the project's files.
	_write_text(dir.path_join(".gdignore"), "")
	_write_text(dir.path_join(".gitignore"), "*\n")

	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var units_path := dir.path_join("sim_%s_units.csv" % stamp)
	var battles_path := dir.path_join("sim_%s_battles.csv" % stamp)
	var summary_path := dir.path_join("sim_%s_summary.txt" % stamp)
	_write_csv(units_path, ["battle", "arv", "team", "result", "unit", "tier", "path", "upgrades",
			"aura", "survived", "damage", "healing", "shielding"], _unit_rows)
	_write_csv(battles_path, ["battle", "arv", "winner", "duration", "timed_out", "team_1", "team_2"], _battle_rows)
	_write_text(summary_path, _summary())
	print("Results written to:\n  %s\n  %s\n  %s" % [units_path, battles_path, summary_path])


func _write_csv(path: String, columns: Array, rows: Array[Dictionary]) -> void:
	var lines: PackedStringArray = [",".join(columns)]
	for row in rows:
		var cells: PackedStringArray = []
		for column in columns:
			var value = row[column]
			if value is float:
				value = snappedf(value, 0.1)
			var text := str(value)
			if text.contains(",") or text.contains("\""):
				text = "\"%s\"" % text.replace("\"", "\"\"")
			cells.append(text)
		lines.append(",".join(cells))
	_write_text(path, "\n".join(lines) + "\n")


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Balance sim: couldn't write %s." % path)
		return
	file.store_string(text)


## Win rates and average output, per unit and per unit + upgrade path.
func _summary() -> String:
	var draws := 0
	var timeouts := 0
	for row in _battle_rows:
		draws += 1 if row["winner"] == 0 else 0
		timeouts += 1 if row["timed_out"] else 0
	var lines: PackedStringArray = [
		"Balance sim: %d battles, ARV %d-%d, max team %d, seed %d" % [_battle_rows.size(), arv_min, arv_max, max_team, seed_value],
		"Draws: %d (%d hit the %.0fs time limit)" % [draws, timeouts, time_limit],
		"Win rate leaves out draws. A unit on the winning team counts as a win. Rows with",
		"few battles are noisy; treat anything under ~50 as a hint, not a result.",
		"",
	]
	lines.append_array(_table("By unit", func(row): return row["unit"]))
	lines.append("")
	lines.append_array(_table("By unit and upgrade path", func(row): return "%s %s" % [row["unit"], row["path"]]))
	return "\n".join(lines) + "\n"


func _table(title: String, key_of: Callable) -> PackedStringArray:
	var groups := {}
	for row in _unit_rows:
		var key: String = key_of.call(row)
		if not groups.has(key):
			groups[key] = {"n": 0, "wins": 0, "losses": 0, "survived": 0, "damage": 0.0, "healing": 0.0, "shielding": 0.0, "aura": 0}
		var g: Dictionary = groups[key]
		g["n"] += 1
		g["wins"] += 1 if row["result"] == "win" else 0
		g["losses"] += 1 if row["result"] == "loss" else 0
		g["survived"] += 1 if row["survived"] else 0
		for stat in ["damage", "healing", "shielding", "aura"]:
			g[stat] += row[stat]

	var keys := groups.keys()
	keys.sort_custom(func(a, b): return _win_rate(groups[a]) > _win_rate(groups[b]))
	var lines: PackedStringArray = [
		title,
		"%-22s %7s %8s %9s %9s %9s %9s %9s" % ["", "battles", "win %", "survive %", "damage", "healing", "shielding", "dmg/aura"],
	]
	for key in keys:
		var g: Dictionary = groups[key]
		var n: float = g["n"]
		lines.append("%-22s %7d %7.1f%% %8.1f%% %9.0f %9.0f %9.0f %9.0f" % [key, g["n"], _win_rate(g) * 100.0,
				g["survived"] / n * 100.0, g["damage"] / n, g["healing"] / n, g["shielding"] / n,
				g["damage"] / maxf(g["aura"], 1.0)])
	return lines


static func _win_rate(group: Dictionary) -> float:
	var decided: int = group["wins"] + group["losses"]
	return float(group["wins"]) / decided if decided > 0 else 0.0
