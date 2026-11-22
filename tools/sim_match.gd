class_name SimMatch
extends RefCounted
## One full computer-vs-computer match under the game's real rules, for the simulators
## (real_sim measures balance with it, match_sim evolves strategies with it): random
## factions, the Opening Shop, combats, Encounters and Ascensions, the real shop, Keepsakes,
## income and damage. Each player plans with its own AiPolicy (the strategy that decides
## which plans get tried); every plan and Ascension option is then tested in battle and the
## best kept, as AiPlanner does, but in this process.
##
## Plan testing uses successive halving: every plan fights a battle or two, only the best
## share go on to fight more, and so on (see `plan_rungs`). The battles go to the plans that
## might win instead of being spread evenly over plans that clearly won't. Battle k of every
## plan uses the same combat seed, so no plan looks better from luckier dice.
## Run it with SimMode on (the simulators turn it on).

const COMBAT_LIMIT := 180.0
const AI_EVAL := preload("res://scripts/match/ai_eval.gd")
const MAX_COMBATS := 40

## Where the battles run (their nodes are added under it).
var host: Node
## Plans made per planning phase.
var candidates := 12
## Successive halving for planning: the total battles a plan has fought after each rung.
## Every plan fights rung 1; the best `keep_share` (at least 2) go on to the next rung.
## [2] is the old even way (every plan 2 battles).
var plan_rungs: Array = [1, 3, 6]
## The same for Encounter picks (only a few options).
var pick_rungs: Array = [2, 6]
## Share of plans kept at each rung.
var keep_share := 1.0 / 3.0
## Seconds a test battle may run before it counts as a draw.
var time_limit := 90.0
## Test battles fought in the last match (for reports).
var battles_fought := 0


func _init(p_host: Node) -> void:
	host = p_host
	var planner := AiPlanner.new()   # the game's own settings, unless told otherwise
	candidates = planner.candidates
	time_limit = planner.time_limit
	planner.free()


## Plays one match. `policies` holds each player's strategy ([bottom, top]). Returns the
## record real_sim writes (see tools/real_sim_report.py), with each player's "policy" index.
func play(match_seed: int, policies: Array) -> Dictionary:
	seed(match_seed)
	battles_fought = 0
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
			await _plan(players[i], policies[i], players[1 - i].last_fielded, players[1 - i].last_fielded_ascensions, combats_done + 1)
		if round_number == 1:
			round_number = 2
			continue
		# Combat
		for p in players:
			MatchRules.auto_place_bench(p)
			p.last_fielded = ArmyUnit.copy_army(p.board_units())
			p.last_fielded_round = round_number
			p.last_fielded_ascensions = p.ascensions.duplicate()
		var r: Dictionary = await BattleArena.fight(host, players[0].units, players[1].units, COMBAT_LIMIT, -1,
				players[0].ascensions, players[1].ascensions)
		ArmySpawner.apply_match_gains(players[0].units, r["gains"].get(1, {}))   # Codger B's rest-of-match gains
		ArmySpawner.apply_match_gains(players[1].units, r["gains"].get(2, {}))
		players[0].reserve += ArmySpawner.reserve_from(r["gains"], 1)   # Von Carrow's bounty
		players[1].reserve += ArmySpawner.reserve_from(r["gains"], 2)
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
			"seconds": (Time.get_ticks_msec() - started) / 1000.0, "test_battles": battles_fought, "players": []}
	for i in 2:
		var p := players[i]
		record["players"].append({"faction": p.faction, "result": result if i == 0 else 1.0 - result,
				"hp": p.hp, "army": _army_text(p.units), "army_aura": p.army_aura(),
				"ascensions": picks[i], "offers": offers[i]})
	record["combat_log"] = combats
	return record


## Planning: `candidates` plans from the player's strategy, tested against the other
## player's last fielded army; the best is kept.
func _plan(p: PlayerState, policy: AiPolicy, opponent_army: Array[ArmyUnit], opponent_ascensions: Array[Ascension], combat_number: int) -> void:
	var plans: Array[PlayerState] = []
	for c in candidates:
		var trial := p.copy()
		policy.make_plan(trial, combat_number, c)
		plans.append(trial)
	p.adopt(plans[await best(plans, opponent_army, opponent_ascensions, p.aura_received, plan_rungs)])


## An Encounter pick, as AiPlanner does it: each offer taken on a copy (a chosen-unit one
## going to the unit it guesses fits best) and tested in battle. Returns what was taken.
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
	p.adopt(plans[await best(plans, opponent_army, opponent_ascensions, p.aura_received, pick_rungs)])
	if p.ascensions.size() <= before:
		return {}
	var taken: Ascension = p.ascensions[-1]
	var holder := MatchRules.holder_of(p.units, taken)
	return {"name": taken.get_display_name(), "tier": taken.tier_text(),
			"unit": holder.data.display_name if holder != null else ""}


## Index of the plan that does best against the opponent (most wins, a draw half a win,
## then surviving-Aura margin), by successive halving over `rungs`.
func best(plans: Array[PlayerState], opponent_army: Array[ArmyUnit], opponent_ascensions: Array[Ascension],
		aura_received: int, rungs: Array) -> int:
	if plans.size() == 1:
		return 0
	var opponent := ArmyUnit.copy_army(opponent_army)
	var opp_asc := opponent_ascensions.duplicate()
	if opponent.is_empty():
		opponent = stand_in(aura_received)
		opp_asc.clear()
	if opponent.is_empty():
		return 0
	var total: int = rungs[rungs.size() - 1]
	var seeds: Array = []
	for k in total:
		seeds.append(randi() & 0x7fffffff)
	var tallies: Array = []
	for i in plans.size():
		tallies.append({"wins": 0, "draws": 0, "losses": 0, "margin": 0.0, "n": 0})
	var alive: Array = range(plans.size())
	for rung in rungs.size():
		var target: int = rungs[rung]
		for i in alive:
			var t: Dictionary = tallies[i]
			var extra: int = target - t["n"]
			if extra <= 0:
				continue
			var tally: Dictionary = await AI_EVAL.score(host, plans[i].units, opponent, extra, time_limit,
					plans[i].ascensions, opp_asc, seeds.slice(t["n"], target))
			for key in ["wins", "draws", "losses"]:
				t[key] += tally[key]
			t["margin"] += tally["margin"] * extra
			t["n"] = target
			battles_fought += extra
		alive.sort_custom(func(a, b):
			var sa := _score(tallies[a])
			var sb := _score(tallies[b])
			return sa > sb or (sa == sb and a < b))   # ties: the earlier plan, as before
		if rung < rungs.size() - 1:
			alive = alive.slice(0, maxi(2, ceili(alive.size() * keep_share)))
	return alive[0]


static func _score(t: Dictionary) -> float:
	var n := maxf(float(t["n"]), 1.0)
	return (t["wins"] + 0.5 * t["draws"]) / n + t["margin"] / n / 1000.0


## Before the first combat there's no army to plan against: a random army worth the Aura
## given so far (the same placeholder the game uses).
static func stand_in(aura: int) -> Array[ArmyUnit]:
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
static func _army_text(army: Array[ArmyUnit]) -> Array:
	return army.map(func(u): return "%s|%s|%d|%d|%s" % [u.data.display_name, RandomTeams.path_label(u.path),
			u.buffs, u.cell.y, "+".join(u.items.map(func(k): return k.get_display_name()))])


## "1,3,6" -> [1, 3, 6]: rungs from a command-line argument, rising, at least one battle.
static func parse_rungs(text: String) -> Array:
	var rungs: Array = []
	for part in text.split(",", false):
		var n := maxi(int(part), 1)
		if rungs.is_empty() or n > rungs[rungs.size() - 1]:
			rungs.append(n)
	return rungs if not rungs.is_empty() else [2]
