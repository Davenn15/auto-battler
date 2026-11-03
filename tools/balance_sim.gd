extends Node2D
## Balance simulator. Runs many battles between random teams of equal ARV, then writes
## every battle and every unit's result to CSV files, plus a summary of win rates.
## Testing tool only: nothing in the game uses this.
##
## Run it from the project folder, without the editor (Godot's _console.exe prints progress):
##   Godot_console.exe --headless --fixed-fps 60 --path . res://tools/balance_sim.tscn -- --battles 500 --arv 6:20
##
## Also writes a matchups file: how much damage each unit dealt to each other unit.
##
## Options (all optional):
##   --battles N      how many battles to run (default 200)
##   --arv A or A:B   ARV of each team. A:B picks a random value in that range each battle (default 10)
##   --max-team N     most units on a team (default 8)
##   --time-limit S   seconds of battle time before the battle is called a draw (default 90)
##   --seed N         random seed, to repeat a run exactly (default: random)
##   --duplicates     let a team have more than one of the same unit (off by default, like the game)
##   --no-frontline-rule  allow teams with no front-liner (by default every team has at least
##                    one melee unit that isn't in the second-row list)
##   --show-placement print where every unit starts and how far it is from the nearest enemy
##   --second-row A,B units that start one row behind the front (default bremes,lunck,wesper;
##                    "none" for nobody)
##   --tier-health A,B,C   multiply max health by tier: A for tier 1, B for tier 2, ... (default all 1)
##   --tier-stats A,B,C    the same for Might, Insight, and Celerity
##   --out PATH       folder for the results (default res://tools/sim_results)
##
## The tier options test stat scaling without changing the game: they apply to every unit
## as it spawns, so summons copy the scaled stats like they would from real ones.
##
## --fixed-fps 60 makes every frame count as 1/60 of a second however fast it really runs,
## so battles play out exactly as in the game, just much faster.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn
const UNITS_DIR := "res://data/units"

var battles: int = 200
var arv_min: int = 10
var arv_max: int = 10
var max_team: int = 8
var time_limit: float = 90.0
var seed_value: int = 0
var allow_duplicates: bool = false
var show_placement: bool = false
var second_row: Array[String] = ["bremes", "lunck", "wesper"]
var require_frontline: bool = true
var tier_health: PackedFloat64Array = []   # index 0 = tier 1; missing tiers count as 1
var tier_stats: PackedFloat64Array = []
var out_dir: String = "res://tools/sim_results"

var _roster: Array[UnitData] = []
var _records: Dictionary = {}     # unit instance id -> that unit's row for the current battle
var _unit_rows: Array[Dictionary] = []
var _battle_rows: Array[Dictionary] = []
var _battle_over: bool = false
var _winner: int = 0              # 0 = draw
var _hits: Dictionary = {}        # "attacker>victim" unit names -> total damage, across all battles
var _faced: Dictionary = {}       # "attacker>victim" -> how many battles they were on opposite teams
var _last_victim: int = 0         # instance id of the unit that was just hit (see VictimTracker)


func _ready() -> void:
	add_to_group("damage_tracker")   # units report damage, healing, and shielding to this group
	_parse_args()
	seed(seed_value)
	_roster = RandomTeams.load_roster(UNITS_DIR)
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
	allow_duplicates = args.has("--duplicates")
	require_frontline = not args.has("--no-frontline-rule")
	show_placement = args.has("--show-placement")
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
			"--second-row":
				second_row.assign(Array() if value == "none" else Array(value.to_lower().split(",")))
			"--tier-health":
				tier_health = value.split_floats(",")
			"--tier-stats":
				tier_stats = value.split_floats(",")
			"--out":
				out_dir = value


# ---------- Running a battle ----------

func _run_battle(index: int, target: int) -> void:
	var teams := {
		1: RandomTeams.make_team(_roster, target, max_team, allow_duplicates, require_frontline, second_row),
		2: RandomTeams.make_team(_roster, target, max_team, allow_duplicates, require_frontline, second_row),
	}
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
	var placement := RandomTeams.place_teams(grid, teams, second_row)
	if show_placement:
		_print_placement(grid, teams, placement)
	for team in teams:
		var cells: Array = placement[team]
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
	for id in _records:   # after start_battle, which clears every status
		(instance_from_id(id) as BattleUnit).add_status(VictimTracker.new(self))

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
	_count_faced()
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
	add_child(unit)   # runs _ready, which sets up stats and health from the data
	_apply_tier_scaling(unit)
	unit.place_at(cell)
	unit.died.connect(_on_unit_died)
	return unit


const SCALED_STATS := [Stats.Stat.MIGHT, Stats.Stat.INSIGHT, Stats.Stat.CELERITY]

## Multiplies a freshly spawned unit's health and attributes by its tier's --tier-health
## and --tier-stats values.
func _apply_tier_scaling(unit: BattleUnit) -> void:
	var health_scale := _tier_value(tier_health, unit.data.tier)
	var stat_scale := _tier_value(tier_stats, unit.data.tier)
	unit.max_health *= health_scale
	unit.health = unit.max_health
	for stat in SCALED_STATS:
		unit.base_stats[stat] = unit.base_stats.get(stat, 0.0) * stat_scale


static func _tier_value(values: PackedFloat64Array, tier: int) -> float:
	return values[tier - 1] if tier - 1 < values.size() else 1.0


## For --show-placement: each unit's starting cell and its distance to the nearest enemy.
func _print_placement(grid: BattleGrid, teams: Dictionary, placement: Dictionary) -> void:
	for team in teams:
		for i in teams[team].size():
			var pick: Dictionary = teams[team][i]
			var nearest := 1000
			for enemy in placement[3 - team]:
				nearest = mini(nearest, grid.get_distance(placement[team][i], enemy))
			print("  team %d  %-10s range %d  cell %s  nearest enemy %d" % [team,
					pick["data"].display_name.capitalize(), RandomTeams.attack_range(pick), placement[team][i], nearest])


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
	# Every damage source calls take_damage on the victim, then record_damage right after,
	# so the victim VictimTracker just saw is the one this damage went to.
	var victim = _records.get(_last_victim)
	var attacker = _records.get(unit_id)
	_last_victim = 0
	if victim != null and attacker != null and amount > 0.0:
		var key := "%s>%s" % [attacker["unit"], victim["unit"]]
		_hits[key] = _hits.get(key, 0.0) + amount


## Notes which unit is being hit, so record_damage knows who the damage went to.
## The game's damage reports only say who dealt the damage, not who took it.
class VictimTracker extends Status:
	var sim: Node

	func _init(owner_sim: Node) -> void:
		sim = owner_sim

	func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
		sim._last_victim = unit.get_instance_id()
		return damage


## Adds one to every attacker > victim pair that was on opposite teams this battle.
func _count_faced() -> void:
	for a in _records.values():
		for v in _records.values():
			if a["team"] != v["team"]:
				var key := "%s>%s" % [a["unit"], v["unit"]]
				_faced[key] = _faced.get(key, 0) + 1


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
		"path": RandomTeams.path_label(pick["path"]), "upgrades": _upgrade_names(data, pick["path"]),
		"aura": unit.get_aura_value(), "survived": true,
		"damage": 0.0, "healing": 0.0, "shielding": 0.0,
	}


## The upgrade level of a path label: "base" = 0, "A" = 1, "A1" = 2.
static func _level_of(label: String) -> int:
	return 0 if label == "base" else label.length()


## The names of the upgrades on a path, e.g. "Stalwart > A1". Upgrades still using the
## default name show as their path label instead.
func _upgrade_names(data: UnitData, path: Array) -> String:
	var names: PackedStringArray = []
	var choices := data.upgrades
	for level in path.size():
		var upgrade: Upgrade = choices[path[level]]
		var is_default := upgrade.upgrade_name == "Upgrade" or upgrade.upgrade_name.is_empty()
		names.append(RandomTeams.path_label(path.slice(0, level + 1)) if is_default else upgrade.upgrade_name)
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
	var matchup_rows: Array[Dictionary] = []
	for key in _faced:
		var names: PackedStringArray = key.split(">")
		var damage: float = _hits.get(key, 0.0)
		matchup_rows.append({"attacker": names[0], "victim": names[1], "battles": _faced[key],
				"damage": damage, "damage_per_battle": damage / _faced[key]})
	matchup_rows.sort_custom(func(a, b): return a["victim"] + a["attacker"] < b["victim"] + b["attacker"])
	var matchups_path := dir.path_join("sim_%s_matchups.csv" % stamp)
	_write_csv(matchups_path, ["victim", "attacker", "battles", "damage", "damage_per_battle"], matchup_rows)
	_write_text(summary_path, _summary())
	print("Results written to:\n  %s\n  %s\n  %s\n  %s" % [units_path, battles_path, matchups_path, summary_path])


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
		"Balance sim: %d battles, ARV %d-%d, max team %d, %s, seed %d" % [_battle_rows.size(), arv_min, arv_max,
				max_team, "duplicates allowed" if allow_duplicates else "no duplicates", seed_value],
		"Extra tier scaling (on top of the game's own): health %s, Might/Insight/Celerity %s" % [_scale_text(tier_health), _scale_text(tier_stats)],
		"Second row: %s. At least one front-liner per team: %s" % [", ".join(second_row) if not second_row.is_empty() else "nobody",
				"yes" if require_frontline else "no"],
		"Draws: %d (%d hit the %.0fs time limit)" % [draws, timeouts, time_limit],
		"Win rate leaves out draws. A unit on the winning team counts as a win. Rows with",
		"few battles are noisy; treat anything under ~50 as a hint, not a result.",
		"",
	]
	lines.append_array(_table("By tier", func(row): return "Tier %d" % row["tier"]))
	lines.append("")
	lines.append_array(_table("By unit", func(row): return row["unit"]))
	lines.append("")
	lines.append_array(_table("By unit and upgrade level", func(row): return "%s L%d" % [row["unit"], _level_of(row["path"])]))
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


## "1 / 1.4 / 1.8" for the summary, or "none" when the option wasn't given.
static func _scale_text(values: PackedFloat64Array) -> String:
	if values.is_empty():
		return "none"
	var parts: PackedStringArray = []
	for v in values:
		parts.append(str(v))
	return " / ".join(parts)
