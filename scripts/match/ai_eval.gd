extends Node2D
## Runs in its own headless copy of the game, started by AiPlanner. Reads a list of
## candidate armies and the army they're up against from a JSON file, fights each
## candidate a few times, and writes how each one did to another JSON file.
##
## Arguments (after --): --in <file> --out <file>
## Input:  {"opponent": [army], "candidates": [[army], ...], "battles": n, "time_limit": s, "seed": n}
## Output: [{"wins": n, "draws": n, "losses": n, "margin": average surviving Aura difference}, ...]


func _ready() -> void:
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
	var results := []
	for candidate in job["candidates"]:
		var army := ArmyUnit.army_from_array(candidate)
		results.append(await score(self, army, opponent, int(job["battles"]), float(job["time_limit"])))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(results))
	file.close()
	await get_tree().process_frame
	get_tree().quit()


## Fights `army` (on the far side, like the computer's army in a real combat) against
## `opponent` `battles` times. Returns {wins, draws, losses, margin}.
static func score(host: Node, army: Array[ArmyUnit], opponent: Array[ArmyUnit], battles: int, time_limit: float) -> Dictionary:
	var tally := {"wins": 0, "draws": 0, "losses": 0, "margin": 0.0}
	for b in battles:
		var r: Dictionary = await BattleArena.fight(host, opponent, army, time_limit)
		match r["winner"]:
			2: tally["wins"] += 1
			1: tally["losses"] += 1
			_: tally["draws"] += 1
		tally["margin"] += r["top_aura"] - r["bottom_aura"]
	tally["margin"] /= maxf(float(battles), 1.0)
	return tally
