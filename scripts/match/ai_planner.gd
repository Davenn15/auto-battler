class_name AiPlanner
extends Node
## The computer opponent's planning phase, "simulate and choose":
## 1. Makes several random but legal plans: what to buy, reroll, combine and equip, and
##    where to stand.
## 2. Fights each plan against the other player's last fielded army, a few battles each,
##    in background copies of the game that stay running all match (AiPool), so the game
##    doesn't freeze while it thinks and never waits for copies to start.
## 3. Keeps the plan that did best.
## Testing uses successive halving (`plan_rungs`): every plan fights a battle, only the best
## share fight more, and so on, so the battles go to the plans that might be best.

signal plan_ready(summary: String)

## How many plans to try each planning phase.
@export var candidates: int = 12
## Battles per plan. More is steadier but slower.
@export var battles_per_candidate: int = 2
## Most copies of the game simulating at once. Never more than the computer's cores less
## one (see _copy_count). A plan's battles can be split over several copies, so even a
## few plans (an Encounter's 3 Ascensions) use every copy.
@export var processes: int = 12   # each copy uses about 175 MB
## Battles per option when picking an Ascension at an Encounter (only a few options, so
## each can get more).
@export var battles_per_ascension: int = 6
## Successive halving: the total battles a plan has fought after each rung. Every plan
## fights the first rung; the best `keep_share` (at least 2) go on to the next. Off, every
## plan fights Battles Per Candidate (or Battles Per Ascension) battles, as before.
@export var halving: bool = true
@export var plan_rungs: Array[int] = [1, 3, 6]
## The same for Encounter picks (only a few options).
@export var pick_rungs: Array[int] = [2, 6]
@export_range(0.1, 1.0, 0.05) var keep_share: float = 1.0 / 3.0
## Seconds a simulated battle may run before it counts as a draw.
@export var time_limit: float = 90.0

## Names this planner in its log line (watching two computers play).
var label := "Opponent"

var busy := false
var _player: PlayerState
var _plans: Array[PlayerState] = []
var _jobs: Array[Dictionary] = []   # {ticket (AiPool), indices}
var _results: Array = []             # per plan: a result dictionary, or null
var _started_ms := 0
var _used_stand_in := false
var _opponent_ascensions: Array[Ascension] = []
var _battles := 2          # most battles any plan fights this phase (the last rung)
var _rungs: Array[int] = []
var _rung := 0
var _alive: Array = []     # plan indices still being tested
var _seeds: Array = []     # battle k of every plan uses seed k (the same dice for all)
var _opponent: Array[ArmyUnit] = []
var _battles_run := 0
var _picking_ascension := false


## Starts planning for `player`. `opponent_army` is the other player's last fielded army;
## empty before the first combat. `opponent_ascensions` are that army's Ascensions. Emits
## plan_ready when `player` has been updated.
func plan(player: PlayerState, opponent_army: Array[ArmyUnit], combat_number: int, opponent_ascensions: Array[Ascension] = []) -> void:
	_begin(player, opponent_ascensions, battles_per_candidate, false)
	for i in candidates:
		var trial := player.copy()
		_random_plan(trial, combat_number, i)
		_plans.append(trial)
	_test_plans(opponent_army)


## Encounter: picks one of `player`'s ascension_offers by fighting its current army with
## each one against the other player's last fielded army. Emits plan_ready once taken.
func pick_ascension(player: PlayerState, opponent_army: Array[ArmyUnit], opponent_ascensions: Array[Ascension] = []) -> void:
	_begin(player, opponent_ascensions, battles_per_ascension, true)
	for slot in player.ascension_offers.size():
		var trial := player.copy()
		# A chosen-unit Ascension goes to the unit it guesses would use it best.
		var unit_index := MatchRules.guess_unit_index(trial, trial.ascension_offers[slot]) \
				if trial.ascension_offers[slot].is_chosen() else -1
		if not MatchRules.take_ascension(trial, slot, unit_index):
			continue
		MatchRules.auto_place_bench(trial)
		_plans.append(trial)
	if _plans.is_empty():   # nothing on offer
		_plans.append(player.copy())
	_test_plans(opponent_army)


func _begin(player: PlayerState, opponent_ascensions: Array[Ascension], battles: int, picking: bool) -> void:
	busy = true
	_player = player
	_started_ms = Time.get_ticks_msec()
	_plans.clear()
	_results.clear()
	_opponent_ascensions = opponent_ascensions.duplicate()
	_picking_ascension = picking
	var rungs: Array[int] = pick_rungs if picking else plan_rungs
	var even: Array[int] = [battles]
	_rungs = rungs.duplicate() if halving and not rungs.is_empty() else even
	_battles = _rungs[_rungs.size() - 1]
	_rung = 0
	_battles_run = 0


func _test_plans(opponent_army: Array[ArmyUnit]) -> void:
	var opponent := ArmyUnit.copy_army(opponent_army)
	_used_stand_in = opponent.is_empty()
	if _used_stand_in:
		opponent = _stand_in_opponent(_player.aura_received)
		_opponent_ascensions.clear()
	if opponent.is_empty() or _plans.size() == 1:
		_finish(0)
		return
	_opponent = opponent
	_results.clear()
	_results.resize(_plans.size())
	_alive = range(_plans.size())
	_seeds.clear()
	for k in _battles:
		_seeds.append(randi() & 0x7fffffff)
	_start_jobs(opponent)


func _process(_delta: float) -> void:
	if not busy or _jobs.is_empty():
		return
	AiPool.pump()
	for job in _jobs.duplicate():
		var entry = AiPool.take(job["ticket"])
		if entry == null:
			continue   # still running (AiPool gives up on it after AiPool.TIMEOUT)
		var parsed = entry["result"]
		if typeof(parsed) == TYPE_ARRAY:
			for k in mini(parsed.size(), job["indices"].size()):
				_add_result(job["indices"][k], parsed[k])
		_jobs.erase(job)
	if _jobs.is_empty():
		_next_rung()


## After a rung: keep the best share and test them more, or finish after the last rung.
func _next_rung() -> void:
	_alive.sort_custom(func(a, b):
		var sa := _score(a)
		var sb := _score(b)
		return sa > sb or (sa == sb and a < b))   # ties: the earlier plan
	if _rung >= _rungs.size() - 1 or _alive.size() <= 1 or not busy:
		_finish(_alive[0] if not _alive.is_empty() else 0)
		return
	_alive = _alive.slice(0, maxi(2, ceili(_alive.size() * keep_share)))
	_rung += 1
	_start_jobs(_opponent)


## Battles plan `index` has fought so far.
func _fought(index: int) -> int:
	var r = _results[index]
	return 0 if r == null else int(r["wins"] + r["draws"] + r["losses"])


## Wins (a draw half a win) per battle, then surviving-Aura margin; -INF if untested.
func _score(index: int) -> float:
	var r = _results[index]
	if r == null:
		return -INF
	return (r["wins"] + 0.5 * r["draws"]) / maxf(float(_fought(index)), 1.0) + r["margin"] / 1000.0


## Adds one copy's tally for plan `index` to what other copies found for it: wins, draws
## and losses add up; the margin becomes the average over all its battles.
func _add_result(index: int, tally: Dictionary) -> void:
	var before = _results[index]
	if before == null:
		_results[index] = tally
		return
	var a := float(before["wins"] + before["draws"] + before["losses"])
	var b := float(tally["wins"] + tally["draws"] + tally["losses"])
	var merged := {"wins": before["wins"] + tally["wins"], "draws": before["draws"] + tally["draws"],
			"losses": before["losses"] + tally["losses"],
			"margin": (before["margin"] * a + tally["margin"] * b) / maxf(a + b, 1.0)}
	_results[index] = merged


## How many copies to run: `processes`, but at most the cores less one (one is left for the
## game itself), and at least one.
func _copy_count() -> int:
	return clampi(mini(processes, OS.get_processor_count() - 1), 1, 64)


## Closed mid-plan: drop its jobs. The copies themselves belong to AiPool, which the match
## closes when it ends.
func _exit_tree() -> void:
	for job in _jobs:
		AiPool.cancel(job["ticket"])
	_jobs.clear()
	busy = false


# ---------- Making plans ----------

## The strategy that decides which plans get tried: the one the match simulator trained
## (data/ai/trained_policy.json) if there is one, otherwise the game's plain default.
var policy := AiPolicy.load_trained()


func _random_plan(p: PlayerState, combat_number: int, variant: int) -> void:
	policy.make_plan(p, combat_number, variant)


## PLACEHOLDER: before the first combat there's no army to plan against, so plans are
## tested against a random army worth the Aura both players have been given so far.
func _stand_in_opponent(aura: int) -> Array[ArmyUnit]:
	var army: Array[ArmyUnit] = []
	var picks := RandomTeams.make_team(MatchRules.roster(), aura, 8, false, true)
	for pick in picks:
		var unit := ArmyUnit.new(pick["data"])
		unit.path.assign(pick["path"])
		army.append(unit)
	var p := PlayerState.new()
	p.units = army
	AiPolicy.lay_out(p)
	return army


# ---------- Simulating ----------

## True in a background copy started to test plans. Such a copy must never start copies of
## its own: if it ever ended up in a match, each copy would start more, without end.
static func is_eval_copy() -> bool:
	return OS.get_cmdline_user_args().has("--ai-eval")


## Starts this rung's battles: each plan still in the running fights up to the rung's total.
func _start_jobs(opponent: Array[ArmyUnit]) -> void:
	_jobs.clear()
	if is_eval_copy():
		push_error("AiPlanner: a background test copy tried to plan; refusing to start more copies.")
		_finish(0)
		return
	# Every plan's battles, cut into chunks and shared out so each copy fights about the
	# same number. A plan whose battles land in several copies has its tallies added up
	# again when they finish (see _process): the same battles, just played side by side.
	# Every plan faces the same dice: battle k of each plan uses the same combat seed, so
	# one plan can't look better than another just by getting luckier rolls.
	var target: int = _rungs[_rung]
	var wanted := 0
	for i in _alive:
		wanted += maxi(target - _fought(i), 0)
	var copies := _copy_count()
	var per_chunk := maxi(1, ceili(float(wanted) / copies))
	var chunks: Array = []   # [plan index, battles, seeds for those battles]
	for i in _alive:
		var first := _fought(i)
		while first < target:
			var n := mini(per_chunk, target - first)
			chunks.append([i, n, _seeds.slice(first, first + n)])
			first += n
	_battles_run += wanted
	var loads: Array = []    # per copy: [battles so far, [chunks]]
	for j in mini(copies, chunks.size()):
		loads.append([0, []])
	for chunk in chunks:   # each chunk to the copy with the fewest battles so far
		var lightest: Array = loads[0]
		for entry in loads:
			if entry[0] < lightest[0]:
				lightest = entry
		lightest[0] += chunk[1]
		lightest[1].append(chunk)
	for j in loads.size():
		var mine: Array = loads[j][1]
		var indices: Array = mine.map(func(c): return c[0])
		var job := {
			"opponent": ArmyUnit.army_to_array(opponent),
			"opponent_ascensions": ArmyUnit.ascensions_to_array(_opponent_ascensions),
			"candidates": indices.map(func(i): return ArmyUnit.army_to_array(_plans[i].units)),
			"candidate_ascensions": indices.map(func(i): return ArmyUnit.ascensions_to_array(_plans[i].ascensions)),
			"candidate_battles": mine.map(func(c): return c[1]),
			"candidate_seeds": mine.map(func(c): return c[2]),
			"battles": _battles, "time_limit": time_limit, "seed": randi(),
		}
		_jobs.append({"ticket": AiPool.submit(job, copies), "indices": indices})
	if _jobs.is_empty():
		_finish(_best_plan())   # nothing started: the best tested so far (plan 0 if none)


## The plan still in the running that did best (most wins, a draw half a win; ties go to
## the bigger surviving-Aura margin, then the earlier plan). Plan 0 if none was tested.
func _best_plan() -> int:
	var best := 0
	var best_score := -INF
	for i in _alive:
		var score := _score(i)
		if score > best_score or (score == best_score and i < best):
			best_score = score
			best = i
	return best


func _finish(index: int) -> void:
	_player.adopt(_plans[index])
	busy = false
	var seconds := (Time.get_ticks_msec() - _started_ms) / 1000.0
	var tested := _results.filter(func(result): return result != null).size()
	var testing := "%d battles, halving %s" % [_battles_run, ",".join(PackedStringArray(_rungs.map(func(rung): return str(rung))))] if _rungs.size() > 1 			else "%d battles each" % _battles
	var summary := "%s planned in %.1fs (%d plans tested, %s%s)" % [
			label, seconds, tested, testing, ", against a stand-in army" if _used_stand_in else ""]
	if _picking_ascension:
		var taken := _player.ascensions[-1].get_display_name() if not _player.ascensions.is_empty() else "nothing"
		var holder := MatchRules.holder_of(_player.units, _player.ascensions[-1]) if not _player.ascensions.is_empty() else null
		if holder != null:
			taken += " for " + holder.label().strip_edges()
		summary = "%s took %s (%d options tested, %s%s)" % [
				label, taken, tested, testing, ", against a stand-in army" if _used_stand_in else ""]
	var r = _results[index] if index < _results.size() else null
	if r != null:
		summary += "; its pick won %d of %d" % [r["wins"], r["wins"] + r["draws"] + r["losses"]]
	_plans.clear()
	plan_ready.emit(summary)
