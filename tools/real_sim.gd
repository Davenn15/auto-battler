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
##     --rungs 1,3,6     successive halving for plans: battles per plan after each rung
##                       (every plan fights the first; the best third go on). See SimMatch.
##     --pick-rungs 2,6  the same for Ascension options
##     --no-halving      the old even testing: --battles N per plan (default 2) and
##                       --pick-battles N per Ascension option (default 6)
##     --seed N
##
## Both players use the computer's strategy (AiPolicy.load_trained(): the trained one in
## data/ai/ if there is one, else the default), and battles run in lean mode (SimMode).
##
## Output: tools/sim_results/real_<time>/matches.jsonl (each worker appends as it goes, so
## a cut-short run still leaves its finished matches).
## Workers play their matches in-process and never start copies of their own.

var total_matches := 100
var workers := 12
var candidates := 12
var battles := 2
var pick_battles := 6
var rungs := "1,3,6"
var pick_rungs := "2,6"
var halving := true
var seed_value := 1


func _ready() -> void:
	SimMode.active = true   # lean battles: no bars, numbers or effects, same fights
	var args := OS.get_cmdline_user_args()
	var planner := AiPlanner.new()   # the game's own settings, unless told otherwise
	candidates = planner.candidates
	battles = planner.battles_per_candidate
	pick_battles = planner.battles_per_ascension
	planner.free()
	total_matches = int(_arg(args, "--matches", str(total_matches)))
	workers = int(_arg(args, "--workers", str(workers)))
	candidates = int(_arg(args, "--candidates", str(candidates)))
	battles = int(_arg(args, "--battles", str(battles)))
	pick_battles = int(_arg(args, "--pick-battles", str(pick_battles)))
	rungs = _arg(args, "--rungs", rungs)
	pick_rungs = _arg(args, "--pick-rungs", pick_rungs)
	halving = not args.has("--no-halving")
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
	var testing := ("halving %s, Ascensions %s" % [rungs, pick_rungs]) if halving else ("%d battles per plan, %d per Ascension" % [battles, pick_battles])
	print("Real sim: %d matches on %d workers (%d plans, %s), seed %d, strategy %s -> %s" %
			[total_matches, count, candidates, testing, seed_value,
			"trained" if AiPolicy.has_trained() else "default", out_dir])
	var pids: Array = []
	for w in count:
		@warning_ignore("integer_division")
		var mine := total_matches / count + (1 if w < total_matches % count else 0)
		var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--fixed-fps", "60",
				"--path", ProjectSettings.globalize_path("res://"), "res://tools/real_sim.tscn", "--",
				"--worker", "--matches", str(mine), "--seed", str(seed_value * 1000 + w),
				"--candidates", str(candidates), "--battles", str(battles), "--pick-battles", str(pick_battles),
				"--rungs", rungs, "--pick-rungs", pick_rungs,
				"--out", out_dir.path_join("w%d.jsonl" % w)]
				+ ([] if halving else ["--no-halving"]))
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
	var sim := SimMatch.new(self)
	sim.candidates = candidates
	sim.plan_rungs = SimMatch.parse_rungs(rungs) if halving else [battles]
	sim.pick_rungs = SimMatch.parse_rungs(pick_rungs) if halving else [pick_battles]
	var policy := AiPolicy.load_trained()
	for m in total_matches:
		var record: Dictionary = await sim.play(randi(), [policy, policy])
		var file := FileAccess.open(out_path, FileAccess.READ_WRITE) if FileAccess.file_exists(out_path) 				else FileAccess.open(out_path, FileAccess.WRITE)
		file.seek_end()
		file.store_string(JSON.stringify(record) + "
")
		file.close()
	await get_tree().process_frame
	get_tree().quit()
