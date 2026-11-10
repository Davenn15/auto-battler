class_name AiPolicy
extends RefCounted
## How the computer opponent makes its candidate plans: a "strategy" of numbers (the
## genome) that biases what it buys, how often it rerolls, saves, combines and equips, and
## how it lays out its army. The planner still tests the plans in battle and keeps the
## best; the strategy decides which plans get tried. The match simulator evolves these.
##
## The default strategy is the plain one the game uses.

## Every number in the genome, with its default and the range evolution may move it in.
const RANGES := {
	"unit_rate": [3.0, 0.5, 6.0],      # weight of each affordable unit slot in the shop
	"upgrade_bias": [1.0, 0.2, 4.0],   # extra weight on upgrades of owned units
	"buff_bias": [1.0, 0.1, 4.0],      # extra weight on Reserve buffs of maxed units
	"shard_rate": [1.0, 0.1, 4.0],     # weight of each affordable Shard slot
	"reroll_rate": [0.3, 0.0, 0.9],    # chance a reroll is one of the options at each step
	"save_rate": [0.08, 0.0, 0.4],     # chance to stop shopping at each step
	"reserve_floor": [0.0, 0.0, 20.0], # Reserve it won't spend below on Shards and rerolls
	"combine_rate": [0.5, 0.0, 1.0],   # chance to combine another pair of loose Shards
	"equip_rate": [0.85, 0.0, 1.0],    # chance to put each loose item on a unit
	"layout_rate": [0.5, 0.0, 1.0],    # chance to re-lay the army front-liners first
	"front_row": [1.0, 0.0, 1.0],      # chance front-liners take the very front row (else one back)
	"back_row": [1.0, 0.0, 1.0],       # chance the others take the very back row (else one forward)
	"center_bias": [0.0, 0.0, 1.0],    # chance to fill columns from the middle outward
}

## How a plan treats Shards. Plans take turns (by variant), so each is tested every round:
##   KEEP: the old habit. Combine loose pairs only sometimes; equip Shards straight away.
##   POOL: take every Shard off the units, combine as many pairs as possible, re-equip.
##   HOLD: combine every loose pair; a leftover Shard waits loose instead of being equipped.
enum ShardHandling { KEEP, POOL, HOLD }
const SHARD_HANDLING := [ShardHandling.KEEP, ShardHandling.POOL, ShardHandling.HOLD]

var genome := {}


func _init() -> void:
	for key in RANGES:
		genome[key] = RANGES[key][0]
	genome["units"] = {}     # unit name -> buy weight multiplier
	genome["paths"] = {}     # unit name -> [chance of A at level 1, chance of the first choice at level 2]
	genome["shards"] = {}    # Shard kind name -> buy weight multiplier
	for data in MatchRules.roster():
		genome["units"][data.display_name] = 1.0
		genome["paths"][data.display_name] = [0.5, 0.5]
	for kind in Shard.NAMES:
		genome["shards"][Shard.NAMES[kind]] = 1.0


static func from_dict(d: Dictionary) -> AiPolicy:
	var policy := AiPolicy.new()
	for key in d:
		policy.genome[key] = d[key]
	return policy


func to_dict() -> Dictionary:
	return genome.duplicate(true)


## A random strategy, for the first generation.
static func random() -> AiPolicy:
	var policy := AiPolicy.new()
	for key in RANGES:
		policy.genome[key] = randf_range(RANGES[key][1], RANGES[key][2])
	for name in policy.genome["units"]:
		policy.genome["units"][name] = exp(randf_range(-1.2, 1.2))
		policy.genome["paths"][name] = [randf(), randf()]
	for name in policy.genome["shards"]:
		policy.genome["shards"][name] = exp(randf_range(-1.2, 1.2))
	return policy


## A copy with small random changes.
func mutated(strength: float = 0.25) -> AiPolicy:
	var child := AiPolicy.from_dict(to_dict())
	var g := child.genome
	for key in RANGES:
		if randf() < 0.35:
			var span: float = RANGES[key][2] - RANGES[key][1]
			g[key] = clampf(g[key] + randfn(0.0, strength * span * 0.5), RANGES[key][1], RANGES[key][2])
	for name in g["units"]:
		if randf() < 0.3:
			g["units"][name] = clampf(g["units"][name] * exp(randfn(0.0, strength * 2.0)), 0.05, 20.0)
		if randf() < 0.2:
			var p: Array = g["paths"][name]
			g["paths"][name] = [clampf(p[0] + randfn(0.0, strength), 0.0, 1.0), clampf(p[1] + randfn(0.0, strength), 0.0, 1.0)]
	for name in g["shards"]:
		if randf() < 0.3:
			g["shards"][name] = clampf(g["shards"][name] * exp(randfn(0.0, strength * 2.0)), 0.05, 20.0)
	return child


## Half of each number from each parent.
static func crossover(a: AiPolicy, b: AiPolicy) -> AiPolicy:
	var child := AiPolicy.from_dict(a.to_dict())
	var g := child.genome
	for key in RANGES:
		if randf() < 0.5:
			g[key] = b.genome[key]
	for table in ["units", "paths", "shards"]:
		for name in g[table]:
			if randf() < 0.5 and b.genome[table].has(name):
				g[table][name] = b.genome[table][name]
	return child


# ---------- Making a plan ----------

## Spends `p`'s money on shop actions chosen by the strategy, then combines, equips and
## places. `variant` 0 always re-lays the army; others follow layout_rate.
func make_plan(p: PlayerState, combat_number: int, variant: int, second_row: Array[String]) -> Dictionary:
	var g := genome
	var stats := {"units": 0, "upgrades": 0, "buffs": 0, "shards": 0, "rerolls": 0, "combines": 0}
	for step in 40:
		var options: Array = []   # [weight, kind, slot]
		for slot in p.unit_offers.size():
			var data := p.unit_offers[slot]
			var info := MatchRules.offer_info(p, data)
			if not MatchRules.can_afford(p, info):
				continue
			var weight: float = g["unit_rate"] * float(g["units"].get(data.display_name, 1.0))
			if info["kind"] == "upgrade":
				weight *= g["upgrade_bias"]
			elif info["kind"] == "buff":
				if p.reserve - info["reserve"] < g["reserve_floor"]:
					continue
				weight *= g["buff_bias"]
			options.append([weight, "unit", slot])
		for slot in p.shard_offers.size():
			if p.reserve - MatchRules.SHARD_COST >= g["reserve_floor"]:
				var name: String = Shard.NAMES[p.shard_offers[slot].first_shard]
				options.append([g["shard_rate"] * float(g["shards"].get(name, 1.0)), "shard", slot])
		if p.reserve - p.reroll_cost >= g["reserve_floor"] + MatchRules.SHARD_COST and randf() < g["reroll_rate"]:
			options.append([1.0, "reroll", 0])
		if options.is_empty() or randf() < g["save_rate"]:
			break
		var pick: Array = _weighted(options)
		match pick[1]:
			"unit":
				var data := p.unit_offers[pick[2]]
				var owned := p.find_unit(data)
				var choice := -1
				if owned != null and not owned.is_maxed():
					choice = _path_choice(owned)
					stats["upgrades"] += 1
				elif owned != null:
					stats["buffs"] += 1
				else:
					stats["units"] += 1
				MatchRules.buy_unit_offer(p, pick[2], choice)
			"shard":
				MatchRules.buy_shard_offer(p, pick[2])
				stats["shards"] += 1
			"reroll":
				MatchRules.reroll(p, combat_number)
				stats["rerolls"] += 1
	# What to do with Shards differs from plan to plan, so the planner's test battles decide
	# whether combining pays off (see SHARD_HANDLING).
	var handling: int = SHARD_HANDLING[variant % SHARD_HANDLING.size()]
	if handling == ShardHandling.POOL:
		_pull_shards_off(p)   # every Shard the army has becomes available to combine
	var combine_all := handling != ShardHandling.KEEP
	while combine_all or randf() < g["combine_rate"]:
		var loose: Array = []
		for i in p.inventory.size():
			if p.inventory[i].is_shard:
				loose.append(i)
		if loose.size() < 2:
			break
		loose.shuffle()
		if MatchRules.combine(p, loose[0], loose[1]):
			stats["combines"] += 1
		else:
			break
	for i in range(p.inventory.size() - 1, -1, -1):
		var open := p.units.filter(func(u): return u.items.size() < BattleUnit.MAX_KEEPSAKES)
		if open.is_empty():
			break
		if handling == ShardHandling.HOLD and p.inventory[i].is_shard:
			continue   # a lone Shard waits loose for a partner
		if randf() < g["equip_rate"]:
			MatchRules.equip(p, open.pick_random(), i)
	if variant == 0 or randf() < g["layout_rate"]:
		lay_out(p, second_row, g)
	MatchRules.auto_place_bench(p)
	return stats


## Takes every Shard off the army's units and back into the inventory. Keepsakes stay on.
static func _pull_shards_off(p: PlayerState) -> void:
	for unit in p.units:
		for i in range(unit.items.size() - 1, -1, -1):
			if unit.items[i].is_shard:
				MatchRules.unequip(p, unit, i)


func _path_choice(unit: ArmyUnit) -> int:
	var count := MatchRules.upgrade_choices(unit).size()
	if count <= 1:
		return 0
	var chances: Array = genome["paths"].get(unit.data.display_name, [0.5, 0.5])
	var first_chance: float = chances[mini(unit.level(), 1)]
	return 0 if randf() < first_chance else randi_range(1, count - 1)


static func _weighted(options: Array) -> Array:
	var total := 0.0
	for option in options:
		total += option[0]
	var roll := randf() * total
	for option in options:
		roll -= option[0]
		if roll <= 0.0:
			return option
	return options[options.size() - 1]


## Front-liners toward the front, everyone else toward the back. With a genome, it picks
## which row each group starts from and whether columns fill from the middle; without
## one, the very front and very back rows in random columns.
static func lay_out(p: PlayerState, second_row: Array[String], g: Dictionary = {}) -> void:
	var front_row := MatchRules.GRID_ROWS / 2 + (0 if randf() < float(g.get("front_row", 1.0)) else 1)
	var back_row := MatchRules.GRID_ROWS - 1 - (0 if randf() < float(g.get("back_row", 1.0)) else 1)
	var centered := randf() < float(g.get("center_bias", 0.0))
	var column_key := {}
	for cell in MatchRules.own_cells():
		var column := cell.x + floori(cell.y / 2.0)
		column_key[cell] = absf(column - (MatchRules.GRID_COLUMNS - 1) / 2.0) + randf() * 0.5 if centered else randf() * 8.0
	var cells := MatchRules.own_cells()
	cells.sort_custom(func(a, b): return absi(a.y - front_row) * 100 + column_key[a] < absi(b.y - front_row) * 100 + column_key[b])
	var back := MatchRules.own_cells()
	back.sort_custom(func(a, b): return absi(a.y - back_row) * 100 + column_key[a] < absi(b.y - back_row) * 100 + column_key[b])
	var taken := {}
	for unit in p.units:
		unit.placed = false
	for unit in p.units:
		var pick := {"data": unit.data, "path": unit.path}
		var list: Array = cells if RandomTeams.is_frontline(pick, second_row) else back
		for cell in list:
			if not taken.has(cell):
				taken[cell] = true
				unit.cell = cell
				unit.placed = true
				break
