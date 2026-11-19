extends Node2D
## Runs in its own headless copy of the game, started by AiPlanner. Reads a list of
## candidate armies and the army they're up against from a JSON file, fights each
## candidate a few times, and writes how each one did to another JSON file.
##
## Two ways to run:
##   One job:  --in <file> --out <file>: fights it, writes the result, quits.
##   Worker:   --worker --dir <folder> --id N (see AiPool): stays running for
##             the whole match. It waits for <folder>/wN_job.json, fights it, writes
##             wN_out.json, and waits for the next. It quits when the game's heartbeat file
##             goes stale (the game closed or crashed), when the folder is removed, after
##             IDLE_QUIT seconds with no work, or when it finds wN_quit.
## Input:  {"opponent": [army], "candidates": [[army], ...], "battles": n, "time_limit": s, "seed": n,
##          "opponent_ascensions": [path], "candidate_ascensions": [[path], ...],
##          "candidate_battles": [n, ...], "candidate_seeds": [[seed, ...], ...]}
##          (all optional; candidate_battles overrides battles; each candidate's battles use
##          its seeds in order, random where there are none)
## Output: [{"wins": n, "draws": n, "losses": n, "margin": average surviving Aura difference}, ...]


const POLL_TIME := 0.02      # seconds between looks for a new job
const PARENT_CHECK := 1.0    # seconds between checks that the game is still running
## The game rewrites <folder>/heartbeat every AiPool.BEAT seconds; older than this and the
## game is gone. (Windows only lets Godot check processes it started itself, so a worker
## can't simply ask whether the game's process is still running.)
const STALE_BEAT := 15
const IDLE_QUIT := 1800.0    # a worker with no work this long quits

var _worker := false
var _dir := ""
var _id := 0
var _busy := false
var _poll := 0.0
var _parent_check := 0.0
var _idle := 0.0


func _ready() -> void:
	SimMode.active = true   # lean battles: no bars, numbers or effects, same fights
	var args := OS.get_cmdline_user_args()
	if args.has("--worker"):
		_worker = true
		for i in args.size() - 1:
			match args[i]:
				"--dir": _dir = args[i + 1]
				"--id": _id = int(args[i + 1])
		return
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
	var results: Array = await _run(job)
	_write(out_path, results)
	await get_tree().process_frame
	get_tree().quit()


## Worker: looks for a job every POLL_TIME, and quits if the game that started it is gone.
func _process(delta: float) -> void:
	if not _worker or _busy:
		return
	_idle += delta
	_parent_check -= delta
	if _parent_check <= 0.0:
		_parent_check = PARENT_CHECK
		var beat := _dir.path_join("heartbeat")
		if not FileAccess.file_exists(beat) 				or Time.get_unix_time_from_system() - FileAccess.get_modified_time(beat) > STALE_BEAT:
			get_tree().quit()
			return
		if _idle > IDLE_QUIT or FileAccess.file_exists(_path("quit")):
			get_tree().quit()
			return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL_TIME
	var job_path := _path("job")
	if not FileAccess.file_exists(job_path):
		return
	var job = JSON.parse_string(FileAccess.get_file_as_string(job_path))
	DirAccess.remove_absolute(job_path)
	if typeof(job) != TYPE_DICTIONARY:
		return
	_busy = true
	_idle = 0.0
	seed(int(job.get("seed", 0)))
	var results: Array = await _run(job)
	results.append({"ticket": job.get("ticket", -1)})   # which job this answers
	# Written under another name, then renamed, so the game never reads half a file.
	_write(_path("out") + ".tmp", results)
	DirAccess.rename_absolute(_path("out") + ".tmp", _path("out"))
	_busy = false


func _path(kind: String) -> String:
	return "%s/w%d_%s.json" % [_dir, _id, kind]


func _write(path: String, results: Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(results))
	file.close()


## Fights every candidate in `job`; returns one tally per candidate.
func _run(job: Dictionary) -> Array:
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
	return results


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
