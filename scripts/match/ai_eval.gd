extends Node2D
## Runs in its own headless copy of the game, started by AiPlanner. Reads a list of
## candidate armies and the army they're up against from a JSON file, fights each
## candidate a few times, and writes how each one did to another JSON file.
##
## Arguments (after --): --in <file> --out <file>
## Input:  {"opponent": [army], "candidates": [[army], ...], "battles": n, "time_limit": s, "seed": n,
##          "opponent_ascensions": [path], "candidate_ascensions": [[path], ...],
##          "candidate_battles": [n, ...], "candidate_seeds": [[seed, ...], ...]}
##          (all optional; candidate_battles overrides battles; each candidate's battles use
##          its seeds in order, random where there are none)
## Output: [{"wins": n, "draws": n, "losses": n, "margin": average surviving Aura difference}, ...]


func _ready() -> void:
	SimMode.active = true   # lean battles: no bars, numbers or effects, same fights
	var args := OS.get_cmdline_user_args()
	var in_path := ""
	var out_path := ""
	for i in args.size() - 1:
		if args[i] == "--in":
			in_path = args[i + 1]
		elif args[i] == "--out":
			out_path = args[i + 1]
	var job = JSON.parse_string(FileAccess.get_file_as_string(in_path))
	if typeof(job) != TYPE_DICTIONARY:
		push_error("ai_eval: couldn't read %s" % in_path)
		get_tree().quit(1)
		return
	seed(int(job.get("seed", 0)))
	_run(job, out_path)


func _run(job: Dictionary, out_path: String) -> void:
	var opponent := ArmyUnit.army_from_array(job["opponent"])
	var opponent_ascensions := ArmyUnit.ascensions_from_array(job.get("opponent_ascensions", []))
	var candidate_ascensions: Array = job.get("candidate_ascensions", [])
	var candidate_battles: Array = job.get("candidate_battles", [])
	var candidate_seeds: Array = job.get("candidate_seeds", [])
	var results := []
	for c in job["candidates"].size():
		var army := ArmyUnit.army_from_array(job["candidates"][c])
		var ascensions := ArmyUnit.ascensions_from_array(candidate_ascensions[c] if c < candidate_ascensions.size() else [])
		var battles := int(candidate_battles[c]) if c < candidate_battles.size() else int(job["battles"])
		var seeds: Array = candidate_seeds[c] if c < candidate_seeds.size() else []
		results.append(await score(self, army, opponent, battles, float(job["time_limit"]), ascensions, opponent_ascensions, seeds))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(results))
	file.close()
	await get_tree().process_frame
	get_tree().quit()


## Fights `army` (on the far side, like the computer's army in a real combat) against
## `opponent` `battles` times, each with its Ascensions; battle b uses `seeds[b]` for its
## combat randomness if given (random otherwise). Returns {wins, draws, losses, margin}.
static func score(host: Node, army: Array[ArmyUnit], opponent: Array[ArmyUnit], battles: int, time_limit: float,
		ascensions: Array[Ascension] = [], opponent_ascensions: Array[Ascension] = [], seeds: Array = []) -> Dictionary:
	var tally := {"wins": 0, "draws": 0, "losses": 0, "margin": 0.0}
	for b in battles:
		var combat_seed := int(seeds[b]) if b < seeds.size() else -1
		var r: Dictionary = await BattleArena.fight(host, opponent, army, time_limit, combat_seed, opponent_ascensions, ascensions)
		match r["winner"]:
			2: tally["wins"] += 1
			1: tally["losses"] += 1
			_: tally["draws"] += 1
		tally["margin"] += r["top_aura"] - r["bottom_aura"]
	tally["margin"] /= maxf(float(battles), 1.0)
	return tally
