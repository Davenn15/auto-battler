class_name AiPlanner
extends Node
## The computer opponent's planning phase, "simulate and choose":
## 1. Makes several random but legal plans: what to buy, reroll, combine and equip, and
##    where to stand.
## 2. Fights each plan against the other player's last fielded army, a few battles each,
##    in separate headless copies of the game (scenes/ai_eval.tscn), so the game doesn't
##    freeze while it thinks.
## 3. Keeps the plan that did best.

signal plan_ready(summary: String)

## How many plans to try each planning phase.
@export var candidates: int = 12
## Battles per plan. More is steadier but slower.
@export var battles_per_candidate: int = 2
## Copies of the game simulating at once.
@export var processes: int = 4
## Seconds a simulated battle may run before it counts as a draw.
@export var time_limit: float = 90.0
## Give up on a copy of the game that takes longer than this (seconds).
@export var process_timeout: float = 120.0
## Units that stand in the second row: the shared list (RandomTeams.second_row_units).
var second_row_units: Array[String] = RandomTeams.second_row_units()

## Names this planner's files and its log line, so two planners can run at once (watching
## two computers play).
var job_prefix := "job"
var label := "Opponent"

var busy := false
var _player: PlayerState
var _plans: Array[PlayerState] = []
var _jobs: Array[Dictionary] = []   # {pid, out, indices}
var _results: Array = []             # per plan: a result dictionary, or null
var _started_ms := 0
var _used_stand_in := false


## Starts planning for `player`. `opponent_army` is the other player's last fielded army;
## empty before the first combat. Emits plan_ready when `player` has been updated.
func plan(player: PlayerState, opponent_army: Array[ArmyUnit], combat_number: int) -> void:
	busy = true
	_player = player
	_started_ms = Time.get_ticks_msec()
	_plans.clear()
	for i in candidates:
		var trial := player.copy()
		_random_plan(trial, combat_number, i)
		_plans.append(trial)
	var opponent := ArmyUnit.copy_army(opponent_army)
	_used_stand_in = opponent.is_empty()
	if _used_stand_in:
		opponent = _stand_in_opponent(player.aura_received)
	if opponent.is_empty() or _plans.size() == 1:
		_finish(0)
		return
	_start_jobs(opponent)


func _process(_delta: float) -> void:
	if not busy or _jobs.is_empty():
		return
	var timed_out := (Time.get_ticks_msec() - _started_ms) / 1000.0 > process_timeout
	for job in _jobs.duplicate():
		if OS.is_process_running(job["pid"]) and not timed_out:
			continue
		if timed_out and OS.is_process_running(job["pid"]):
			OS.kill(job["pid"])
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(job["out"]))
		if typeof(parsed) == TYPE_ARRAY:
			for k in mini(parsed.size(), job["indices"].size()):
				_results[job["indices"][k]] = parsed[k]
		_jobs.erase(job)
	if _jobs.is_empty():
		_finish(_best_plan())


# ---------- Making plans ----------

## The strategy that decides which plans get tried. The default is the game's plain one;
## the match simulator evolves others.
var policy := AiPolicy.new()


func _random_plan(p: PlayerState, combat_number: int, variant: int) -> void:
	policy.make_plan(p, combat_number, variant, second_row_units)


## PLACEHOLDER: before the first combat there's no army to plan against, so plans are
## tested against a random army worth the Aura both players have been given so far.
func _stand_in_opponent(aura: int) -> Array[ArmyUnit]:
	var army: Array[ArmyUnit] = []
	var picks := RandomTeams.make_team(MatchRules.roster(), aura, 8, false, true, second_row_units)
	for pick in picks:
		var unit := ArmyUnit.new(pick["data"])
		unit.path.assign(pick["path"])
		army.append(unit)
	var p := PlayerState.new()
	p.units = army
	AiPolicy.lay_out(p, second_row_units)
	return army


# ---------- Simulating ----------

## True in a background copy started to test plans. Such a copy must never start copies of
## its own: if it ever ended up in a match, each copy would start more, without end.
static func is_eval_copy() -> bool:
	return OS.get_cmdline_user_args().has("--ai-eval")


func _start_jobs(opponent: Array[ArmyUnit]) -> void:
	_results.clear()
	_results.resize(_plans.size())
	_jobs.clear()
	if is_eval_copy():
		push_error("AiPlanner: a background test copy tried to plan; refusing to start more copies.")
		_finish(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://ai"))
	var count := clampi(processes, 1, _plans.size())
	for j in count:
		var indices: Array = []
		for i in range(j, _plans.size(), count):
			indices.append(i)
		var job := {
			"opponent": ArmyUnit.army_to_array(opponent),
			"candidates": indices.map(func(i): return ArmyUnit.army_to_array(_plans[i].units)),
			"battles": battles_per_candidate, "time_limit": time_limit, "seed": randi(),
		}
		var in_path := ProjectSettings.globalize_path("user://ai/%s_%d_in.json" % [job_prefix, j])
		var out_path := ProjectSettings.globalize_path("user://ai/%s_%d_out.json" % [job_prefix, j])
		var file := FileAccess.open(in_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(job))
		file.close()
		DirAccess.remove_absolute(out_path)
		# The copy starts at the main menu, which sends it straight to the evaluation scene
		# when it sees --ai-eval (an exported game can't be told which scene to open). From
		# the editor it also needs to be told where the project is.
		var args := PackedStringArray(["--headless", "--fixed-fps", "60"])
		if not OS.has_feature("template"):
			args.append_array(["--path", ProjectSettings.globalize_path("res://")])
		args.append_array(["--", "--ai-eval", "--in", in_path, "--out", out_path])
		var pid := OS.create_process(OS.get_executable_path(), args)
		if pid <= 0:
			push_warning("AiPlanner: couldn't start a simulation; using an untested plan.")
			continue
		_jobs.append({"pid": pid, "out": out_path, "indices": indices})
	if _jobs.is_empty():
		_finish(0)


## Most wins (a draw is half a win); ties go to the bigger surviving-Aura margin.
func _best_plan() -> int:
	var best := 0
	var best_score := -INF
	for i in _results.size():
		var r = _results[i]
		if r == null:
			continue
		var battles := float(r["wins"] + r["draws"] + r["losses"])
		var score: float = (r["wins"] + 0.5 * r["draws"]) / maxf(battles, 1.0) + r["margin"] / 1000.0
		if score > best_score:
			best_score = score
			best = i
	return best


func _finish(index: int) -> void:
	_player.adopt(_plans[index])
	busy = false
	var seconds := (Time.get_ticks_msec() - _started_ms) / 1000.0
	var tested := _results.filter(func(result): return result != null).size()
	var summary := "%s planned in %.1fs (%d plans tested, %d battles each%s)" % [
			label, seconds, tested, battles_per_candidate, ", against a stand-in army" if _used_stand_in else ""]
	var r = _results[index] if index < _results.size() else null
	if r != null:
		summary += "; its pick won %d of %d" % [r["wins"], r["wins"] + r["draws"] + r["losses"]]
	_plans.clear()
	plan_ready.emit(summary)
