extends Node
## Computer-vs-computer match simulator, with strategy evolution.
##
## Coordinator (default): evolves a population of AI strategies (AiPolicy genomes). Each
## generation every strategy plays a few full prototype matches against others; the best
## survive and breed. Matches run in parallel worker copies of the game. At the end the
## best strategy plays the default one, and everything is written to tools/sim_results/.
##
##   godot --headless --fixed-fps 60 --path . res://tools/match_sim.tscn -- [options]
##     --generations N    (default 12)    --population N (default 16)
##     --matches N        matches per strategy per generation (default 4)
##     --workers N        parallel copies of the game (default 12)
##     --candidates N     plans tried per planning phase (default 8)
##     --battles N        test battles per plan (default 2)
##     --final N          best-vs-default matches at the end (default 24)
##     --seed N
##
## Worker (started by the coordinator): --worker --in <job.json> --out <result.json>

const COMBAT_LIMIT := 180.0     # same safety net as the match screen
const PLAN_BATTLE_LIMIT := 90.0
const MAX_COMBATS := 40

var generations := 12
var population := 16
var matches_per := 4
var workers := 12
var candidates := 8
var battles := 2
var final_matches := 24
var seed_value := 1
var out_dir := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--worker"):
		_worker(args)
		return
	_parse(args)
	seed(seed_value)
	if args.has("--ablate"):
		_ablate(_arg(args, "--ablate", ""))
		return
	_coordinate()


## Which parts of a strategy matter: for each group of genes, the strategy with that group
## put back to default plays `final_matches` matches against the default strategy.
##   ... match_sim.tscn -- --ablate <champion.json> --final 24 --workers 12
const ABLATION_GROUPS := {
	"none (full champion)": [],
	"shop spending": ["unit_rate", "upgrade_bias", "buff_bias", "shard_rate", "reroll_rate", "save_rate", "reserve_floor"],
	"unit preferences": ["units"],
	"upgrade paths": ["paths"],
	"shard preferences": ["shards"],
	"combine + equip": ["combine_rate", "equip_rate"],
	"layout": ["layout_rate", "front_row", "back_row", "center_bias"],
}


func _ablate(path: String) -> void:
	var champion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	out_dir = ProjectSettings.globalize_path("res://tools/sim_results/ablation_%s" % stamp)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var default := AiPolicy.new().to_dict()
	var jobs: Array = []
	var group_names: Array = ABLATION_GROUPS.keys()
	for gi in group_names.size():
		var variant := champion.duplicate(true)
		for key in ABLATION_GROUPS[group_names[gi]]:
			variant[key] = default[key]
		for i in final_matches:
			var first := i % 2 == 0
			jobs.append({"a": variant if first else default, "b": default if first else variant,
					"a_id": gi * 2 if first else gi * 2 + 1, "b_id": gi * 2 + 1 if first else gi * 2, "gen": gi, "seed": randi()})
	print("Ablation: %d groups x %d matches -> %s" % [group_names.size(), final_matches, out_dir])
	var records: Array = await _run_matches(jobs)
	var log_file := FileAccess.open(out_dir.path_join("matches.jsonl"), FileAccess.WRITE)
	var score := {}
	var hp := {}
	var count := {}
	for r in records:
		log_file.store_line(JSON.stringify(r))
		var gi: int = r["gen"]
		var side := "a" if int(r["a_id"]) == gi * 2 else "b"
		var other := "b" if side == "a" else "a"
		score[gi] = score.get(gi, 0.0) + float(r[side]["result"])
		hp[gi] = hp.get(gi, 0.0) + float(r[side]["hp"]) - float(r[other]["hp"])
		count[gi] = count.get(gi, 0) + 1
	log_file.close()
	var lines := PackedStringArray(["Champion with one group reset to default, vs the default strategy:"])
	for gi in group_names.size():
		var n: float = maxf(count.get(gi, 0), 1)
		lines.append("  %-22s %5.1f / %d  (%5.1f%%)   avg HP lead %+.1f" % [group_names[gi], score.get(gi, 0.0), int(n), score.get(gi, 0.0) / n * 100.0, hp.get(gi, 0.0) / n])
	var f := FileAccess.open(out_dir.path_join("ablation.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("\n".join(lines))
	get_tree().quit()


func _arg(args: PackedStringArray, flag: String, fallback: String) -> String:
	var i := args.find(flag)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback


func _parse(args: PackedStringArray) -> void:
	generations = int(_arg(args, "--generations", str(generations)))
	population = int(_arg(args, "--population", str(population)))
	matches_per = int(_arg(args, "--matches", str(matches_per)))
	workers = int(_arg(args, "--workers", str(workers)))
	candidates = int(_arg(args, "--candidates", str(candidates)))
	battles = int(_arg(args, "--battles", str(battles)))
	final_matches = int(_arg(args, "--final", str(final_matches)))
	seed_value = int(_arg(args, "--seed", str(seed_value)))


# =====================================================================
# Coordinator
# =====================================================================

func _coordinate() -> void:
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	out_dir = ProjectSettings.globalize_path("res://tools/sim_results/match_sim_%s" % stamp)
	DirAccess.make_dir_recursive_absolute(out_dir)
	print("Match sim: %d generations x %d strategies x %d matches, %d workers, %d plans x %d battles per phase, seed %d" %
			[generations, population, matches_per, workers, candidates, battles, seed_value])
	print("  results: %s" % out_dir)
	var started := Time.get_ticks_msec()

	var pop: Array = [AiPolicy.new().to_dict()]   # the game's default strategy, plus random ones
	while pop.size() < population:
		pop.append(AiPolicy.random().to_dict())
	var history: Array = []
	var log_file := FileAccess.open(out_dir.path_join("matches.jsonl"), FileAccess.WRITE)

	for gen in generations:
		var pairs := _pairings(pop.size())
		var jobs: Array = []
		for pair in pairs:
			jobs.append({"a": pop[pair[0]], "b": pop[pair[1]], "a_id": pair[0], "b_id": pair[1], "gen": gen, "seed": randi()})
		var records: Array = await _run_matches(jobs)
		var score := {}
		var played := {}
		for r in records:
			log_file.store_line(JSON.stringify(r))
			for side in ["a", "b"]:
				var id: int = r[side + "_id"]
				var other := "b" if side == "a" else "a"
				var s: float = r[side]["result"] + (r[side]["hp"] - r[other]["hp"]) / 640.0
				score[id] = score.get(id, 0.0) + s
				played[id] = played.get(id, 0) + 1
		var ranked: Array = range(pop.size())
		ranked.sort_custom(func(x, y): return score.get(x, 0.0) / maxf(played.get(x, 1), 1) > score.get(y, 0.0) / maxf(played.get(y, 1), 1))
		var best: int = ranked[0]
		var fitness: Array = ranked.map(func(i): return snappedf(score.get(i, 0.0) / maxf(played.get(i, 1), 1), 0.01))
		history.append({"gen": gen, "fitness": fitness, "best": pop[best]})
		print("Gen %d done (%.0f min): best %.2f, median %.2f, %d matches" % [gen + 1,
				(Time.get_ticks_msec() - started) / 60000.0, fitness[0], fitness[floori(fitness.size() / 2.0)], records.size()])
		_write_json("best_gen_%02d.json" % (gen + 1), pop[best])
		if gen < generations - 1:
			pop = _next_generation(pop, ranked)
	log_file.close()

	# Final check: the best strategy against the game's default one.
	var champion: Dictionary = history[history.size() - 1]["best"]
	var finals: Array = []
	for i in final_matches:
		var champ_first := i % 2 == 0
		finals.append({"a": champion if champ_first else AiPolicy.new().to_dict(), "b": AiPolicy.new().to_dict() if champ_first else champion,
				"a_id": 0 if champ_first else 1, "b_id": 1 if champ_first else 0, "gen": -1, "seed": randi()})
	var final_records: Array = await _run_matches(finals)
	var final_file := FileAccess.open(out_dir.path_join("final_matches.jsonl"), FileAccess.WRITE)
	var champ_score := 0.0
	for r in final_records:
		final_file.store_line(JSON.stringify(r))
		champ_score += r["a"]["result"] if r["a_id"] == 0 else r["b"]["result"]
	final_file.close()
	print("Final: evolved strategy vs default: %.1f / %d" % [champ_score, final_records.size()])
	_write_json("history.json", history)
	_write_json("champion.json", champion)
	print("Done in %.0f min." % ((Time.get_ticks_msec() - started) / 60000.0))
	get_tree().quit()


## Each strategy plays `matches_per` matches against random others.
func _pairings(count: int) -> Array:
	var pairs: Array = []
	for round_index in matches_per:
		var order: Array = range(count)
		order.shuffle()
		for i in range(0, count - 1, 2):
			pairs.append([order[i], order[i + 1]])
	return pairs


## Keeps the best quarter as they are; fills the rest with children of the top half.
func _next_generation(pop: Array, ranked: Array) -> Array:
	var next: Array = []
	var elites := maxi(floori(pop.size() / 4.0), 1)
	for i in elites:
		next.append(pop[ranked[i]])
	var parents: Array = ranked.slice(0, maxi(floori(pop.size() / 2.0), 2))
	while next.size() < pop.size():
		var a := AiPolicy.from_dict(pop[parents.pick_random()])
		var child := a
		if randf() < 0.5:
			child = AiPolicy.crossover(a, AiPolicy.from_dict(pop[parents.pick_random()]))
		next.append(child.mutated().to_dict())
	return next


## Splits the matches over worker copies of the game and waits for all of them.
func _run_matches(jobs: Array) -> Array:
	var tmp := out_dir.path_join("tmp")
	DirAccess.make_dir_recursive_absolute(tmp)
	var count := clampi(workers, 1, jobs.size())
	var running: Array = []
	for w in count:
		var mine: Array = []
		for i in range(w, jobs.size(), count):
			mine.append(jobs[i])
		var in_path := tmp.path_join("w%d_in.json" % w)
		var out_path := tmp.path_join("w%d_out.json" % w)
		var file := FileAccess.open(in_path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"matches": mine, "candidates": candidates, "battles": battles}))
		file.close()
		DirAccess.remove_absolute(out_path)
		var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--fixed-fps", "60",
				"--path", ProjectSettings.globalize_path("res://"), "res://tools/match_sim.tscn",
				"--", "--worker", "--in", in_path, "--out", out_path])
		running.append({"pid": pid, "out": out_path})
	var records: Array = []
	while not running.is_empty():
		await get_tree().create_timer(1.0).timeout
		for job in running.duplicate():
			if OS.is_process_running(job["pid"]):
				continue
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(job["out"]))
			if typeof(parsed) == TYPE_ARRAY:
				records.append_array(parsed)
			else:
				push_warning("A worker produced no results.")
			running.erase(job)
	return records


func _write_json(file: String, data) -> void:
	var f := FileAccess.open(out_dir.path_join(file), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()


# =====================================================================
# Worker: plays matches
# =====================================================================

func _worker(args: PackedStringArray) -> void:
	var job = JSON.parse_string(FileAccess.get_file_as_string(_arg(args, "--in", "")))
	candidates = int(job["candidates"])
	battles = int(job["battles"])
	var results: Array = []
	for m in job["matches"]:
		seed(int(m["seed"]))
		var record: Dictionary = await _play_match(AiPolicy.from_dict(m["a"]), AiPolicy.from_dict(m["b"]))
		record["a_id"] = m["a_id"]
		record["b_id"] = m["b_id"]
		record["gen"] = m["gen"]
		results.append(record)
	var file := FileAccess.open(_arg(args, "--out", ""), FileAccess.WRITE)
	file.store_string(JSON.stringify(results))
	file.close()
	await get_tree().process_frame
	get_tree().quit()


## One full match between two strategies, following the prototype's rules. Player A
## stands at the bottom in combat, B on the far side.
func _play_match(policy_a: AiPolicy, policy_b: AiPolicy) -> Dictionary:
	var players: Array[PlayerState] = [PlayerState.new(), PlayerState.new()]
	var policies := [policy_a, policy_b]
	var totals := [{}, {}]
	var combats: Array = []
	var round_number := 1
	var combats_done := 0
	while true:
		# Planning: both plan against the other's last fielded army.
		for i in 2:
			MatchRules.start_planning(players[i], combats_done + 1)
		for i in 2:
			var stats: Dictionary = await _plan(players[i], policies[i], players[1 - i].last_fielded, combats_done + 1)
			for key in stats:
				totals[i][key] = totals[i].get(key, 0) + stats[key]
		if round_number == 1:
			round_number += 1   # Opening Shop done: round 2 is the first combat
			continue
		# Combat
		for p in players:
			MatchRules.auto_place_bench(p)
			p.last_fielded = ArmyUnit.copy_army(p.board_units())
			p.last_fielded_round = round_number
		var r: Dictionary = await BattleArena.fight(self, players[0].units, players[1].units, COMBAT_LIMIT)
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
				"a_army": _army_text(players[0].last_fielded), "b_army": _army_text(players[1].last_fielded),
				"a_aura": players[0].army_aura(), "b_aura": players[1].army_aura(),
				"a_left": r["bottom_aura"], "b_left": r["top_aura"], "damage": damage})
		combats_done += 1
		if not players[0].is_alive() or not players[1].is_alive() or combats_done >= MAX_COMBATS:
			break
		round_number += 1
	var result_a := 0.5
	if players[0].is_alive() and not players[1].is_alive():
		result_a = 1.0
	elif players[1].is_alive() and not players[0].is_alive():
		result_a = 0.0
	return {"rounds": round_number, "combats": combats,
			"a": _player_record(players[0], totals[0], result_a),
			"b": _player_record(players[1], totals[1], 1.0 - result_a)}


## Tries the strategy's candidate plans against `opponent` and keeps the best, like
## AiPlanner, but in this process. Returns the chosen plan's shop counts.
func _plan(p: PlayerState, policy: AiPolicy, opponent_army: Array[ArmyUnit], combat_number: int) -> Dictionary:
	var opponent := ArmyUnit.copy_army(opponent_army)
	if opponent.is_empty():
		opponent = _stand_in(p.aura_received)
	var best: PlayerState = null
	var best_stats := {}
	var best_score := -INF
	for c in candidates:
		var trial := p.copy()
		var stats := policy.make_plan(trial, combat_number, c)
		var score := 0.0
		for b in battles:
			var r: Dictionary = await BattleArena.fight(self, opponent, trial.units, PLAN_BATTLE_LIMIT)
			score += 1.0 if r["winner"] == 2 else (0.5 if r["winner"] == 0 else 0.0)
			score += (r["top_aura"] - r["bottom_aura"]) / 1000.0
		if score > best_score:
			best_score = score
			best = trial
			best_stats = stats
	p.adopt(best)
	return best_stats


## Before the first combat there's nothing to plan against: a random army of the same Aura
## (the same placeholder the game uses).
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


func _player_record(p: PlayerState, totals: Dictionary, result: float) -> Dictionary:
	return {"result": result, "hp": p.hp, "aura_left": p.aura, "reserve_left": p.reserve,
			"loose_items": p.inventory.size(), "army": _army_text(p.units), "army_aura": p.army_aura(),
			"shop": totals}
