extends Node
## Real-game match simulator: computer vs computer, full matches with the game's actual
## rules and the game's own computer opponent. Factions are random, Encounters happen and
## Ascensions are picked the way the computer picks them in a match (test battles), the
## shop, Keepsakes and income are the real ones. Writes one line per match for analysis.
##
##   godot --headless --fixed-fps 60 --path . res://tools/real_sim.tscn -- [options]
##     --matches N       total matches (default 100)
##     --workers N       parallel copies of the game (default 12)
##     --candidates N    plans tried per planning phase (default: AiPlanner's, 12)
##     --battles N       test battles per plan (default: AiPlanner's, 2)
##     --pick-battles N  test battles per Ascension option (default: AiPlanner's, 6)
##     --seed N
##
## Output: tools/sim_results/real_<time>/matches.jsonl (each worker appends as it goes, so
## a cut-short run still leaves its finished matches).
## Workers play their matches in-process and never start copies of their own.

const COMBAT_LIMIT := 180.0
const MAX_COMBATS := 40

var total_matches := 100
var workers := 12
var candidates := 12
var battles := 2
var pick_battles := 6
var time_limit := 90.0
var seed_value := 1
const AI_EVAL := preload("res://scripts/match/ai_eval.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var planner := AiPlanner.new()   # the game's own settings, unless told otherwise
	candidates = planner.candidates
	battles = planner.battles_per_candidate
	pick_battles = planner.battles_per_ascension
	time_limit = planner.time_limit
	planner.free()
	total_matches = int(_arg(args, "--matches", str(total_matches)))
	workers = int(_arg(args, "--workers", str(workers)))
	candidates = int(_arg(args, "--candidates", str(candidates)))
	battles = int(_arg(args, "--battles", str(battles)))
	pick_battles = int(_arg(args, "--pick-battles", str(pick_battles)))
	seed_value = int(_arg(args, "--seed", str(randi())))
	if args.has("--worker"):
		_worker(args)
	else:
		_coordinate()


func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback


# ---------- Coordinator ----------

func _coordinate() -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var out_dir := ProjectSettings.globalize_path("res://tools/sim_results/real_%s" % stamp)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var out_path := out_dir.path_join("matches.jsonl")
	FileAccess.open(out_path, FileAccess.WRITE).close()
	var count := clampi(workers, 1, total_matches)
	print("Real sim: %d matches on %d workers (%d plans x %d battles, %d battles per Ascension), seed %d -> %s" %
			[total_matches, count, candidates, battles, pick_battles, seed_value, out_dir])
	var pids: Array = []
	for w in count:
		var mine := total_matches / count + (1 if w < total_matches % count else 0)
		var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--fixed-fps", "60",
				"--path", ProjectSettings.globalize_path("res://"), "res://tools/real_sim.tscn", "--",
				"--worker", "--matches", str(mine), "--seed", str(seed_value * 1000 + w),
				"--candidates", str(candidates), "--battles", str(battles), "--pick-battles", str(pick_battles),
				"--out", out_dir.path_join("w%d.jsonl" % w)])
		pids.append(pid)
	var started := Time.get_ticks_msec()
	var last_report := 0
	while true:
		await get_tree().create_timer(5.0).timeout
		var running := pids.filter(func(p): return OS.is_process_running(p)).size()
		var done := 0
		for w in count:
			var path := out_dir.path_join("w%d.jsonl" % w)
			if FileAccess.file_exists(path):
				done += FileAccess.get_file_as_string(path).count("\n")
		var minutes := (Time.get_ticks_msec() - started) / 60000.0
		if done != last_report or running == 0:
			print("  %d / %d matches (%.1f min, %d workers running)" % [done, total_matches, minutes, running])
			last_report = done
		if running == 0:
			break
	# Gather every worker's lines into one file.
	var all := FileAccess.open(out_path, FileAccess.WRITE)
	for w in count:
		var path := out_dir.path_join("w%d.jsonl" % w)
		if FileAccess.file_exists(path):
			all.store_string(FileAccess.get_file_as_string(path))
	all.close()
	print("Done: %s" % out_path)
	get_tree().quit()


# ---------- Worker ----------

func _worker(args: PackedStringArray) -> void:
	seed(seed_value)
	var out_path := _arg(args, "--out", "")
	for m in total_matches:
		var record: Dictionary = await _play_match(randi())
		var file := FileAccess.open(out_path, FileAccess.READ_WRITE) if FileAccess.file_exists(out_path) \
				else FileAccess.open(out_path, FileAccess.WRITE)
		file.seek_end()
		file.store_string(JSON.stringify(record) + "\n")
		file.close()
	await get_tree().process_frame
	get_tree().quit()


## One full match with the real rules: Opening Shop, then combat and Encounter rounds in
## turn until someone falls. Player 0 fights at the bottom.
func _play_match(match_seed: int) -> Dictionary:
	seed(match_seed)
	var factions := MatchRules.factions()
	var players: Array[PlayerState] = [PlayerState.new(), PlayerState.new()]
	for i in 2:
		players[i].faction = factions[randi() % factions.size()]
		players[i].player_name = "P%d" % i
	var picks: Array = [[], []]      # each Ascension taken: {name, tier, round, unit}
	var offers: Array = [[], []]     # each Ascension offered
	var combats: Array = []
	var round_number := 1
	var combats_done := 0
	var started := Time.get_ticks_msec()
	while true:
		# Planning: each plans against the other's last fielded army, like the computer does.
		for i in 2:
			MatchRules.start_planning(players[i], combats_done + 1)
		for i in 2:
			await _plan(players[i], players[1 - i].last_fielded, players[1 - i].last_fielded_ascensions, combats_done + 1)
		if round_number == 1:
			round_number = 2
			continue
		# Combat
		for p in players:
			MatchRules.auto_place_bench(p)
			p.last_fielded = ArmyUnit.copy_army(p.board_units())
			p.last_fielded_round = round_number
			p.last_fielded_ascensions = p.ascensions.duplicate()
		var r: Dictionary = await BattleArena.fight(self, players[0].units, players[1].units, COMBAT_LIMIT, -1,
				players[0].ascensions, players[1].ascensions)
		var damage := [0, 0]
		match r["winner"]:
			1: damage[1] = MatchRules.loss_damage(round_number, r["bottom_aura"])
			2: damage[0] = MatchRules.loss_damage(round_number, r["top_aura"])
			_:
				damage[0] = MatchRules.draw_damage(round_number, r["top_aura"])
				damage[1] = MatchRules.draw_damage(round_number, r["bottom_aura"])
		for i in 2:
			players[i].hp -= damage[i]
			MatchRules.pay_income(players[i], round_number)
		combats.append({"round": round_number, "winner": r["winner"], "time": snappedf(r["time"], 0.1),
				"armies": [_army_text(players[0].last_fielded), _army_text(players[1].last_fielded)],
				"aura": [players[0].army_aura(), players[1].army_aura()],
				"hp": [players[0].hp, players[1].hp]})
		combats_done += 1
		if not players[0].is_alive() or not players[1].is_alive() or combats_done >= MAX_COMBATS:
			break
		# Encounter round
		round_number += 1
		if MatchRules.is_encounter_round(round_number):
			for i in 2:
				MatchRules.roll_ascension_offers(players[i], round_number)
				for a in players[i].ascension_offers:
					offers[i].append(a.get_display_name())
				var taken: Dictionary = await _pick(players[i], players[1 - i].last_fielded, players[1 - i].last_fielded_ascensions)
				if not taken.is_empty():
					taken["round"] = round_number
					picks[i].append(taken)
		round_number += 1
	var result := 0.5
	if players[0].is_alive() and not players[1].is_alive():
		result = 1.0
	elif players[1].is_alive() and not players[0].is_alive():
		result = 0.0
	var record := {"seed": match_seed, "rounds": round_number, "combats": combats.size(),
			"seconds": (Time.get_ticks_msec() - started) / 1000.0, "players": []}
	for i in 2:
		var p := players[i]
		record["players"].append({"faction": p.faction, "result": result if i == 0 else 1.0 - result,
				"hp": p.hp, "army": _army_text(p.units), "army_aura": p.army_aura(),
				"ascensions": picks[i], "offers": offers[i]})
	record["combat_log"] = combats
	return record


## The computer's planning, as AiPlanner does it, but in this process: `candidates` plans,
## each fought `battles` times (the same dice for every plan) against the other player's
## last fielded army; the best is kept.
func _plan(p: PlayerState, opponent_army: Array[ArmyUnit], opponent_ascensions: Array[Ascension], combat_number: int) -> void:
	var policy := AiPolicy.new()
	var plans: Array[PlayerState] = []
	for c in candidates:
		var trial := p.copy()
		policy.make_plan(trial, combat_number, c)
		plans.append(trial)
	p.adopt(plans[await _best(plans, opponent_army, opponent_ascensions, p.aura_received, battles)])


## An Encounter pick, as AiPlanner does it: each offer taken on a copy (a chosen-unit one
## going to the unit it guesses fits best) and fought `pick_battles` times. Returns what
## was taken.
func _pick(p: PlayerState, opponent_army: Array[ArmyUnit], opponent_ascensions: Array[Ascension]) -> Dictionary:
	var plans: Array[PlayerState] = []
	for slot in p.ascension_offers.size():
		var trial := p.copy()
		var unit_index := MatchRules.guess_unit_index(trial, trial.ascension_offers[slot]) \
				if trial.ascension_offers[slot].is_chosen() else -1
		if MatchRules.take_ascension(trial, slot, unit_index):
			MatchRules.auto_place_bench(trial)
			plans.append(trial)
	if plans.is_empty():
		return {}
	var before := p.ascensions.size()
	p.adopt(plans[await _best(plans, opponent_army, opponent_ascensions, p.aura_received, pick_battles)])
	if p.ascensions.size() <= before:
		return {}
	var taken: Ascension = p.ascensions[-1]
	var holder := MatchRules.holder_of(p.units, taken)
	return {"name": taken.get_display_name(), "tier": taken.tier_text(),
			"unit": holder.data.display_name if holder != null else ""}


## Index of the plan that does best against the opponent (most wins, then margin).
func _best(plans: Array[PlayerState], opponent_army: Array[ArmyUnit], opponent_ascensions: Array[Ascension],
		aura_received: int, n: int) -> int:
	if plans.size() == 1:
		return 0
	var opponent := ArmyUnit.copy_army(opponent_army)
	var opp_asc := opponent_ascensions.duplicate()
	if opponent.is_empty():
		opponent = _stand_in(aura_received)
		opp_asc.clear()
	if opponent.is_empty():
		return 0
	var seeds: Array = []
	for k in n:
		seeds.append(randi() & 0x7fffffff)
	var best := 0
	var best_score := -INF
	for i in plans.size():
		var tally: Dictionary = await AI_EVAL.score(self, plans[i].units, opponent, n, time_limit,
				plans[i].ascensions, opp_asc, seeds)
		var score: float = (tally["wins"] + 0.5 * tally["draws"]) / float(n) + tally["margin"] / 1000.0
		if score > best_score:
			best_score = score
			best = i
	return best


func _stand_in(aura: int) -> Array[ArmyUnit]:
	var army: Array[ArmyUnit] = []
	for pick in RandomTeams.make_team(MatchRules.roster(), aura, 8, false, true):
		var unit := ArmyUnit.new(pick["data"])
		unit.path.assign(pick["path"])
		army.append(unit)
	var holder := PlayerState.new()
	holder.units = army
	AiPolicy.lay_out(holder)
	return army


## "Garth|A1|0|row 7|Crusher+Might Shard" per unit: name, path, buffs, row, items.
func _army_text(army: Array[ArmyUnit]) -> Array:
	return army.map(func(u): return "%s|%s|%d|%d|%s" % [u.data.display_name, RandomTeams.path_label(u.path),
			u.buffs, u.cell.y, "+".join(u.items.map(func(k): return k.get_display_name()))])
