class_name MatchRules
extends RefCounted
## The rules of a match, as numbers and small functions: money, the shop, items, the board
## and damage. Both the screen and the computer opponent go through these, so they always
## play by the same rules.

const START_HP := 64
const START_RESERVE := 10
## Loss damage starts from this, plus half the round number (see round_damage).
const ROUND_DAMAGE_BASE := 3

# Match Aura, new numbers (Economy.tier_rework) and old ones.
const NEW_START_AURA := 10
const OLD_START_AURA := 6
## The most Aura a player is ever given in a match, counting the starting Aura.
const NEW_MAX_AURA_RECEIVED := 90
const OLD_MAX_AURA_RECEIVED := 48
## Aura paid after each player combat (1st, 2nd, ...). With the 10 to start they add up to
## exactly the 90 cap on the 8th combat; later combats pay none.
const NEW_AURA_INCOME: Array[int] = [4, 6, 8, 9, 11, 12, 14, 16]
## Loss damage from survivors is their Aura divided by this, rounded down.
const NEW_SURVIVOR_DIVISOR := 5.0
const OLD_SURVIVOR_DIVISOR := 3.0


static func start_aura() -> int:
	return NEW_START_AURA if Economy.tier_rework else OLD_START_AURA


static func max_aura_received() -> int:
	return NEW_MAX_AURA_RECEIVED if Economy.tier_rework else OLD_MAX_AURA_RECEIVED

const UNIT_OFFERS := 3
const SHARD_OFFERS := 3
const SHARD_COST := 3
const SHARD_SELL := 2
## From this combat on (4th combat = round 5), the shop also offers one random full
## Keepsake at a discount. It rerolls and locks with the rest of the shop.
const KEEPSAKE_FIRST_COMBAT := 4
const KEEPSAKE_COST := 5
## A loose keepsake sells for this share of what it cost.
const KEEPSAKE_SELL_SHARE := 2.0 / 3.0
const REROLL_START := 1
const REROLL_STEP := 1

## Which upcoming combat (1st, 2nd, ...) each tier starts appearing in the shop.
const TIER_FIRST_COMBAT := {1: 1, 2: 1, 3: 3, 4: 5}

## Size of the board. Must match the BattleGrid in the match scene.
const GRID_COLUMNS := 8
const GRID_ROWS := 8

const UNITS_DIR := "res://data/units"
const ASCENSIONS_DIR := "res://data/ascensions"
const KEEPSAKES_DIR := "res://data/keepsakes"

static var _roster: Array[UnitData] = []
static var _pools: Dictionary = {}
static var _ascension_pools: Dictionary = {}   # faction name ("" = Neutral) -> Array[Ascension]
static var _ascensions_by_key: Dictionary = {}  # Ascension.key -> Ascension


static func roster() -> Array[UnitData]:
	if _roster.is_empty():
		_roster = RandomTeams.load_roster(UNITS_DIR)
	return _roster


# ---------- Factions ----------
# A unit's faction is the folder it lives in: data/units/<faction>/<tier>/<unit>/.

const DEFAULT_FACTION := "Sword Court"


## "Sword Court" for res://data/units/sword-court/tier 1/garth/garth.tres.
static func faction_of(data: UnitData) -> String:
	var folder := data.resource_path.trim_prefix(UNITS_DIR + "/").get_slice("/", 0)
	return faction_name(folder)


## A faction folder's name as players see it: "sword-court" -> "Sword Court".
static func faction_name(folder: String) -> String:
	var words := folder.replace("_", " ").replace("-", " ").split(" ", false)
	for i in words.size():
		words[i] = words[i].capitalize()
	return " ".join(words)


## Every faction that has at least one unit, the default first, then by name.
static func factions() -> PackedStringArray:
	var names := PackedStringArray()
	for data in roster():
		var name := faction_of(data)
		if not names.has(name):
			names.append(name)
	names.sort()
	if names.has(DEFAULT_FACTION):
		names.remove_at(names.find(DEFAULT_FACTION))
		names.insert(0, DEFAULT_FACTION)
	return names


## The units a player of `faction` can buy.
static func roster_for(faction: String) -> Array[UnitData]:
	return roster().filter(func(d): return faction_of(d) == faction)


static func shards() -> Array:
	return _keepsake_pools()["shards"]


static func keepsakes() -> Array:
	return _keepsake_pools()["keepsakes"]


static func _keepsake_pools() -> Dictionary:
	if _pools.is_empty():
		_pools = RandomTeams.load_keepsakes(KEEPSAKES_DIR)
	return _pools


# ---------- Rounds and money ----------

## Combats are rounds 2, 4, 6, ... (an Encounter round between each). Income and loss
## damage are sized as when combats were rounds 3, 5, 7, ..., so they use this paced round:
## 3 for round 2, 5 for round 4, and so on (the same numbers per combat as before).
static func paced_round(round_number: int) -> int:
	return round_number + 1


## Reserve each player gets after a player combat in round `round_number`.
static func combat_income(round_number: int) -> int:
	return paced_round(round_number)


## Aura each player gets after a player combat in round `round_number` (before the cap).
## With the tier rework it's that combat's entry in NEW_AURA_INCOME (combats are rounds
## 2, 4, 6, ...); otherwise the paced round.
static func aura_income(round_number: int) -> int:
	if not Economy.tier_rework:
		return paced_round(round_number)
	var combat := round_number / 2 - 1   # 0 for the first combat (round 2)
	return NEW_AURA_INCOME[combat] if combat >= 0 and combat < NEW_AURA_INCOME.size() else 0


## Pays both kinds of income. Aura stops once the player has been given max_aura_received().
static func pay_income(player: PlayerState, round_number: int) -> Dictionary:
	var income := combat_income(round_number)
	var aura := clampi(aura_income(round_number), 0, max_aura_received() - player.aura_received)
	player.aura += aura
	player.aura_received += aura
	player.reserve += income
	return {"aura": aura, "reserve": income}


## Damage to the loser of a player combat in round `round_number`, when the winner has
## `surviving_aura` Aura of units left (upgrades count; summons and keepsakes don't):
## the round part plus the survivor part.
static func loss_damage(round_number: int, surviving_aura: int) -> int:
	return round_damage(round_number) + survivor_damage(surviving_aura)


## The part of a loss that comes from the winner's surviving units: their Aura divided by
## 5 (3 before the tier rework), rounded down.
static func survivor_damage(surviving_aura: int) -> int:
	return floori(surviving_aura / (NEW_SURVIVOR_DIVISOR if Economy.tier_rework else OLD_SURVIVOR_DIVISOR))


## The part of a loss that comes from the round: starts higher and grows half as fast
## as the paced round (4 for the first combat, 5 for the second, 6 for the third, ...).
static func round_damage(round_number: int) -> int:
	return ROUND_DAMAGE_BASE + floori(paced_round(round_number) / 2.0)


## Draws: each player takes half of what they'd take for losing, rounded down.
static func draw_damage(round_number: int, enemy_surviving_aura: int) -> int:
	return floori(loss_damage(round_number, enemy_surviving_aura) / 2.0)


# ---------- Units and upgrades ----------

static func max_level(data: UnitData) -> int:
	return RandomTeams.paths_by_level(data).size() - 1


## What the next upgrade for `unit` can be: [{index, upgrade}].
static func upgrade_choices(unit: ArmyUnit) -> Array:
	var choices := []
	var options: Array[Upgrade] = []
	if unit.level() == 0:
		options = unit.data.upgrades
	elif unit.level() == 1:
		options = unit.data.upgrades[unit.path[0]].next_choices
	for i in options.size():
		choices.append({"index": i, "upgrade": options[i]})
	return choices


## TESTING (2026-11-16): the Aura upgrade system, picked on the main menu before a match
## (online, both players use the host's choice). true = upgrades are bought from an owned
## unit's upgrade menu for Aura, during planning only, and a shop copy of a unit you own
## always buys its Reserve stat buff. false = the old system: the shop copy is the upgrade.
static var aura_upgrades := false


## Aura the next upgrade of `unit` costs (the same tier prices the shop used). -1 if maxed.
static func upgrade_cost(unit: ArmyUnit) -> int:
	if unit.is_maxed():
		return -1
	return Economy.tier_aura_costs(unit.data.tier)[unit.level() + 1]


## Whether `player` can buy `unit`'s next upgrade from its upgrade menu right now.
static func can_buy_upgrade(player: PlayerState, unit: ArmyUnit) -> bool:
	return aura_upgrades and player.units.has(unit) and not unit.is_maxed() \
			and player.aura >= upgrade_cost(unit)


## Aura upgrade system: buys `unit`'s next upgrade, `choice` picking the path (an index
## from upgrade_choices). Returns false if it isn't allowed.
static func buy_upgrade(player: PlayerState, unit: ArmyUnit, choice: int) -> bool:
	if not can_buy_upgrade(player, unit):
		return false
	if choice < 0 or choice >= upgrade_choices(unit).size():
		return false
	player.aura -= upgrade_cost(unit)
	unit.path.append(choice)
	return true


static func buff_cost(tier: int, buffs_bought: int) -> int:
	return 2 * tier * (buffs_bought + 1)


## What buying `data` from the shop means for this player:
## {kind: "buy" | "upgrade" | "buff", aura: cost, reserve: cost}.
static func offer_info(player: PlayerState, data: UnitData) -> Dictionary:
	var owned := player.find_unit(data)
	var costs: Array = Economy.tier_aura_costs(data.tier)
	if owned == null:
		return {"kind": "buy", "aura": costs[0], "reserve": 0}
	if not owned.is_maxed() and not aura_upgrades:
		return {"kind": "upgrade", "aura": costs[owned.level() + 1], "reserve": 0}
	return {"kind": "buff", "aura": 0, "reserve": owned.next_buff_cost()}


static func can_afford(player: PlayerState, info: Dictionary) -> bool:
	return player.aura >= info["aura"] and player.reserve >= info["reserve"]


## Buys shop slot `slot`. For an upgrade, `choice` picks the path (an index from
## upgrade_choices). Returns false if it isn't allowed.
static func buy_unit_offer(player: PlayerState, slot: int, choice: int = -1) -> bool:
	if slot < 0 or slot >= player.unit_offers.size():
		return false
	var data := player.unit_offers[slot]
	var info := offer_info(player, data)
	if not can_afford(player, info):
		return false
	match info["kind"]:
		"buy":
			player.units.append(ArmyUnit.new(data))
		"upgrade":
			var owned := player.find_unit(data)
			if choice < 0 or choice >= upgrade_choices(owned).size():
				return false
			owned.path.append(choice)
		"buff":
			player.find_unit(data).buffs += 1
	player.aura -= info["aura"]
	player.reserve -= info["reserve"]
	player.unit_offers.remove_at(slot)
	return true


# ---------- Rounds and Encounters ----------
# Opening Shop (round 1) -> Combat (2) -> Encounter (3) -> Combat (4) -> Encounter (5) -> ...

enum EncounterKind { FACTION, NEUTRAL }
## Ascensions offered at each Encounter.
const ASCENSION_OFFERS := 3
## Rerolling one of an Encounter's Ascensions: costs this much Reserve. Each card has its
## own reroll button, but they share the price: any reroll raises it by the step for all
## of them. Back to the start at the next Encounter.
const ASCENSION_REROLL_START := 2
const ASCENSION_REROLL_STEP := 1
## Each type's Encounters offer tier 1, 2, 3, 4 in turn; after that, that type's
## Encounters are skipped.
const MAX_ASCENSION_TIER := 4
## How likely a unit-specific Ascension is to be offered, next to an army-wide one (1):
## when you own one of its units (bench counts), and when you own none of them.
const OWNED_UNIT_WEIGHT := 3.0
const UNOWNED_UNIT_WEIGHT := 1.0 / 3.0


static func is_combat_round(round_number: int) -> bool:
	return round_number >= 2 and round_number % 2 == 0


static func is_encounter_round(round_number: int) -> bool:
	return round_number >= 3 and round_number % 2 == 1


## 1 for the first Encounter (round 3), 2 for the second (round 5), ...
static func encounter_number(round_number: int) -> int:
	return (round_number - 1) / 2


## Faction Ascensions at the 1st Encounter, Neutral at the 2nd, then the cycle repeats.
static func encounter_kind(number: int) -> EncounterKind:
	return EncounterKind.FACTION if number % 2 == 1 else EncounterKind.NEUTRAL


## The tier an Encounter offers: Faction Encounters are the odd-numbered ones and Neutral
## the even, so each type's 1st is tier 1, its 2nd tier 2, and so on.
static func encounter_tier(number: int) -> int:
	return (number + 1) / 2


static func encounter_title(kind: EncounterKind, faction: String) -> String:
	return "%s Ascension" % faction if kind == EncounterKind.FACTION else "Neutral Ascension"


## Every Ascension of `faction`'s pool ("" for the Neutral pool).
static func ascension_pool(faction: String) -> Array[Ascension]:
	if _ascension_pools.is_empty():
		for folder in DirAccess.get_directories_at(ASCENSIONS_DIR):
			if folder == "scripts":
				continue
			var key := "" if folder == "neutral" else faction_name(folder)
			var pool: Array[Ascension] = []
			_collect_ascensions(ASCENSIONS_DIR.path_join(folder), pool)
			_ascension_pools[key] = pool
	var found: Array[Ascension] = []
	found.assign(_ascension_pools.get(faction, []))
	return found


## Every Ascension in `dir` and the folders inside it (e.g. "tier 1"). An AscensionFamily
## file adds each of its versions.
static func _collect_ascensions(dir: String, pool: Array[Ascension]) -> void:
	for listed in DirAccess.get_files_at(dir):
		var file := listed.trim_suffix(".remap")   # exported builds list "x.tres.remap"
		if not file.ends_with(".tres"):
			continue
		var path := dir.path_join(file)
		var loaded := load(path)
		if loaded is Ascension:
			_register_ascension(loaded, path, null, pool)
		elif loaded is AscensionFamily:
			for i in loaded.versions.size():
				if loaded.versions[i] != null:
					_register_ascension(loaded.versions[i], "%s#%d" % [path, i], loaded, pool)
	for sub in DirAccess.get_directories_at(dir):
		_collect_ascensions(dir.path_join(sub), pool)


static func _register_ascension(ascension: Ascension, key: String, family: AscensionFamily, pool: Array[Ascension]) -> void:
	ascension.key = key
	ascension.family = family
	_ascensions_by_key[key] = ascension
	pool.append(ascension)


## The Ascension saved or sent as `key` (see Ascension.key), or null.
static func ascension_by_key(key: String) -> Ascension:
	ascension_pool("")   # loads every pool the first time
	if _ascensions_by_key.has(key):
		return _ascensions_by_key[key]
	return load(key) as Ascension if ResourceLoader.exists(key) else null


## Up to ASCENSION_OFFERS random Ascensions for the Encounter of `round_number`: that
## Encounter's tier only, leaving out any version of one the player already has. Empty
## past tier 4 or when that pool has none left (the Encounter is then skipped).
static func roll_ascension_offers(player: PlayerState, round_number: int, exclude: Array = []) -> void:
	var pool := _offerable(player, round_number).filter(func(a): return not exclude.has(a))
	var weights: Array = pool.map(func(a): return ascension_weight(player, a))
	player.ascension_offers.clear()
	while player.ascension_offers.size() < ASCENSION_OFFERS and not pool.is_empty():
		var pick := _weighted_pick(weights)
		player.ascension_offers.append(pool[pick])
		pool.remove_at(pick)
		weights.remove_at(pick)


## A random index into `weights`, each as likely as its weight.
static func _weighted_pick(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var roll := randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return weights.size() - 1


## Every Ascension the Encounter of `round_number` could offer `player`: its tier, none
## they own a version of, none they can't benefit from or pick a unit for.
static func _offerable(player: PlayerState, round_number: int) -> Array[Ascension]:
	var number := encounter_number(round_number)
	var kind := encounter_kind(number)
	var tier := encounter_tier(number)
	var pool := ascension_pool(player.faction if kind == EncounterKind.FACTION else "")
	pool = pool.filter(func(a): return a.offered_at(tier) and not player.ascensions.any(func(owned): return a.same_family(owned)) \
			and (not a.is_chosen() or player.units.any(func(u): return a.can_pick(u))))
	pool = pool.filter(func(a): return ascension_weight(player, a) > 0.0)   # never one they can't use
	var result: Array[Ascension] = []
	result.assign(pool)
	return result


## True if rerolling a card would show an Ascension not already on offer.
static func can_reroll_ascensions(player: PlayerState, round_number: int) -> bool:
	return _offerable(player, round_number).any(func(a): return not player.ascension_offers.has(a))


## Rerolls the Ascension in `slot` for the Reserve price, which then goes up by the step
## for every card. The new one is none of those on offer (nor the one it replaces); the
## other cards stay. False if they can't pay or nothing new is left.
static func reroll_ascension(player: PlayerState, round_number: int, slot: int) -> bool:
	if slot < 0 or slot >= player.ascension_offers.size():
		return false
	if player.reserve < player.ascension_reroll_cost or not can_reroll_ascensions(player, round_number):
		return false
	var pool := _offerable(player, round_number).filter(func(a): return not player.ascension_offers.has(a))
	var weights: Array = pool.map(func(a): return ascension_weight(player, a))
	player.reserve -= player.ascension_reroll_cost
	player.ascension_reroll_cost += ASCENSION_REROLL_STEP
	player.ascension_offers[slot] = pool[_weighted_pick(weights)]
	return true


## How likely `ascension` is to be offered to `player`; 0 = never (they couldn't benefit).
## Army-wide ones: 1. Unit-specific ones (a unit, a Beam, a branch): 3x if a unit they own
## benefits or still can on its path (with Aura they'll have for its upgrades), 1/3x if
## they'd have to buy one they can still afford, 0 if neither. A pair (needs all): 3x
## with both owned, 1x with one, 1/3x with none, 0 if the missing ones can't be afforded.
static func ascension_weight(player: PlayerState, ascension: Ascension) -> float:
	if not ascension.has_unit_requirement():
		return 1.0
	var budget := aura_budget(player)
	if ascension.needs_all_affected:
		var owned := 0
		var cost := 0
		for data in ascension.affected_units:
			var unit := player.find_unit(data)
			var need := _cost_to_benefit(ascension, data, unit)
			if need < 0:
				return 0.0
			cost += need
			owned += int(unit != null)
		if cost > budget:
			return 0.0
		if owned == ascension.affected_units.size():
			return OWNED_UNIT_WEIGHT
		return 1.0 if owned > 0 else UNOWNED_UNIT_WEIGHT
	for unit in player.units:
		var need := _cost_to_benefit(ascension, unit.data, unit)
		if need >= 0 and need <= budget:
			return OWNED_UNIT_WEIGHT
	for data in roster_for(player.faction):
		if player.find_unit(data) != null:
			continue   # owned: covered above (and no duplicates)
		var need := _cost_to_benefit(ascension, data, null)
		if need >= 0 and need <= budget:
			return UNOWNED_UNIT_WEIGHT
	return 0.0


## The Aura `player` has or will still be given this match (up to the cap): the most they
## could spend on new units and upgrades from here.
static func aura_budget(player: PlayerState) -> int:
	return player.aura + maxi(max_aura_received() - player.aura_received, 0)


## The Aura it would take for a unit of `data` (`owned`, or bought if null) to benefit from
## `ascension`: buying it and/or the upgrades it still needs. -1 if it never could.
static func _cost_to_benefit(ascension: Ascension, data: UnitData, owned: ArmyUnit) -> int:
	var path: Array = owned.path if owned != null else []
	var level := ascension.level_to_benefit(data, path)
	if level < 0:
		return -1
	var have := Economy.unit_aura_value(data.tier, owned.level()) if owned != null else 0
	return Economy.unit_aura_value(data.tier, level) - have


## Takes the offered Ascension at `slot`; the rest of the offer goes away. A chosen-unit
## one also needs `unit_index`, the unit in player.units it's given to.
static func take_ascension(player: PlayerState, slot: int, unit_index: int = -1) -> bool:
	if slot < 0 or slot >= player.ascension_offers.size():
		return false
	var ascension := player.ascension_offers[slot]
	if ascension.is_chosen():
		if unit_index < 0 or unit_index >= player.units.size() or not ascension.can_pick(player.units[unit_index]):
			return false
		player.units[unit_index].ascensions.append(ascension)
	player.ascensions.append(ascension)
	player.ascension_offers.clear()
	# Buffs a unit they don't own yet: their next fresh shop is sure to offer it.
	var roster := roster_for(player.faction)
	for data in ascension.affected_units:
		if data != null and player.find_unit(data) == null and roster.has(data) and not player.promised_units.has(data):
			player.promised_units.append(data)
	return true


## The computer's pick for a chosen-unit Ascension: the eligible unit with the most Aura in
## it (tier and upgrades), then the most items. -1 if none can take it.
static func guess_unit_index(player: PlayerState, ascension: Ascension) -> int:
	var best := -1
	for i in player.units.size():
		var unit := player.units[i]
		if not ascension.can_pick(unit):
			continue
		if best < 0 or unit.aura_value() > player.units[best].aura_value() \
				or (unit.aura_value() == player.units[best].aura_value() and unit.items.size() > player.units[best].items.size()):
			best = i
	return best


## The unit in `army` a chosen-unit Ascension was given to, or null.
static func holder_of(army: Array[ArmyUnit], ascension: Ascension) -> ArmyUnit:
	for unit in army:
		if unit.ascensions.has(ascension):
			return unit
	return null


# ---------- The shop ----------

## Fills the shop for a new planning phase and resets the reroll price. A locked shop is
## kept as it was left (bought slots stay empty) instead, and the lock comes off.
static func start_planning(player: PlayerState, combat_number: int) -> void:
	player.reroll_cost = REROLL_START
	if player.shop_locked:
		player.shop_locked = false
		return   # a promised unit waits for the next fresh shop
	roll_unit_offers(player, combat_number, player.promised_units)
	player.promised_units.clear()
	roll_shard_offers(player)
	roll_keepsake_offer(player, combat_number)


static func tier_unlocked(tier: int, combat_number: int) -> bool:
	return combat_number >= TIER_FIRST_COMBAT.get(tier, 1)


## Three different units of the player's faction, from the tiers unlocked for `combat_number`.
## Units in `promised` (whose tier is unlocked) are sure to be among them.
static func roll_unit_offers(player: PlayerState, combat_number: int, promised: Array[UnitData] = []) -> void:
	var pool := roster_for(player.faction).filter(func(d): return tier_unlocked(d.tier, combat_number))
	pool.shuffle()
	var offers: Array[UnitData] = []
	for data in promised:
		if pool.has(data) and offers.size() < UNIT_OFFERS:
			offers.append(data)
			pool.erase(data)
	offers.append_array(pool.slice(0, UNIT_OFFERS - offers.size()))
	offers.shuffle()   # so the promised one isn't always in the first slot
	player.unit_offers.assign(offers)


## Three different Shards.
static func roll_shard_offers(player: PlayerState) -> void:
	var pool := shards().duplicate()
	pool.shuffle()
	player.shard_offers.assign(pool.slice(0, SHARD_OFFERS))


## One random Keepsake once they're unlocked for `combat_number`, else none.
static func roll_keepsake_offer(player: PlayerState, combat_number: int) -> void:
	player.keepsake_offer = keepsakes().pick_random() if keepsake_unlocked(combat_number) else null


static func keepsake_unlocked(combat_number: int) -> bool:
	return combat_number >= KEEPSAKE_FIRST_COMBAT


## Rerolls the units, the Shards and the Keepsake together. The price goes up each time.
static func reroll(player: PlayerState, combat_number: int) -> bool:
	if player.reserve < player.reroll_cost:
		return false
	player.reserve -= player.reroll_cost
	player.reroll_cost += REROLL_STEP
	roll_unit_offers(player, combat_number)
	roll_shard_offers(player)
	roll_keepsake_offer(player, combat_number)
	return true


static func buy_shard_offer(player: PlayerState, slot: int) -> bool:
	if slot < 0 or slot >= player.shard_offers.size() or player.reserve < SHARD_COST:
		return false
	player.reserve -= SHARD_COST
	player.inventory.append(player.shard_offers[slot])
	player.shard_offers.remove_at(slot)
	return true


static func buy_keepsake_offer(player: PlayerState) -> bool:
	if player.keepsake_offer == null or player.reserve < KEEPSAKE_COST:
		return false
	player.reserve -= KEEPSAKE_COST
	player.inventory.append(player.keepsake_offer)
	player.keepsake_offer = null
	return true


# ---------- Items ----------

static func sell_value(item: Keepsake) -> int:
	return SHARD_SELL if item.is_shard else floori(item.get_reserve_value() * KEEPSAKE_SELL_SHARE)


## Sells a Shard or keepsake from the inventory (keepsakes on a unit stay on it).
static func sell_item(player: PlayerState, index: int) -> bool:
	if index < 0 or index >= player.inventory.size():
		return false
	player.reserve += sell_value(player.inventory[index])
	player.inventory.remove_at(index)
	return true


## The keepsake two Shards make, or null.
static func combine_result(a: Keepsake, b: Keepsake) -> Keepsake:
	if a == null or b == null or not a.is_shard or not b.is_shard:
		return null
	for keepsake in keepsakes():
		var k := keepsake as Keepsake
		if (k.first_shard == a.first_shard and k.second_shard == b.first_shard) \
				or (k.first_shard == b.first_shard and k.second_shard == a.first_shard):
			return k
	return null


## Combines two Shards from the inventory into their keepsake, which goes in the inventory.
static func combine(player: PlayerState, index_a: int, index_b: int) -> bool:
	if index_a == index_b or index_a < 0 or index_b < 0 \
			or index_a >= player.inventory.size() or index_b >= player.inventory.size():
		return false
	var result := combine_result(player.inventory[index_a], player.inventory[index_b])
	if result == null:
		return false
	for index in [maxi(index_a, index_b), mini(index_a, index_b)]:   # higher first, so the lower index stays right
		player.inventory.remove_at(index)
	player.inventory.append(result)
	return true


## Moves an item from the inventory onto a unit. Keepsakes stay on for good.
static func equip(player: PlayerState, unit: ArmyUnit, index: int) -> bool:
	if index < 0 or index >= player.inventory.size() or unit.items.size() >= BattleUnit.MAX_KEEPSAKES:
		return false
	unit.items.append(player.inventory[index])
	player.inventory.remove_at(index)
	return true


## Takes a Shard off a unit, back to the inventory. Keepsakes can't come off.
static func unequip(player: PlayerState, unit: ArmyUnit, item_index: int) -> bool:
	if item_index < 0 or item_index >= unit.items.size() or not unit.items[item_index].is_shard:
		return false
	player.inventory.append(unit.items[item_index])
	unit.items.remove_at(item_index)
	return true


# ---------- The board ----------

## The player's own cells (the bottom half), back row first, each row left to right.
static func own_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for r in range(GRID_ROWS - 1, floori(GRID_ROWS / 2.0) - 1, -1):
		var q_start := -floori(r / 2.0)
		for i in GRID_COLUMNS:
			cells.append(Vector2i(q_start + i, r))
	return cells


static func is_own_cell(cell: Vector2i) -> bool:
	return own_cells().has(cell)


## The cell straight across the board: how the other player's army is laid out on your
## screen, since both players see themselves at the bottom.
static func mirror_cell(cell: Vector2i) -> Vector2i:
	var r := GRID_ROWS - 1 - cell.y
	var column := cell.x + floori(cell.y / 2.0)
	var mirrored_column := GRID_COLUMNS - 1 - column
	return Vector2i(mirrored_column - floori(r / 2.0), r)


## Places a unit, swapping with whoever stood there. Bench units moved off a cell go to
## the bench; a unit that already stood somewhere swaps cells with the occupant.
static func place(player: PlayerState, unit: ArmyUnit, cell: Vector2i) -> bool:
	if not is_own_cell(cell):
		return false
	var other := player.unit_at(cell)
	if other != null and other != unit:
		if unit.placed:
			other.cell = unit.cell
		else:
			other.placed = false
	unit.cell = cell
	unit.placed = true
	return true


static func bench(unit: ArmyUnit) -> void:
	unit.placed = false


## Puts every bench unit on the board: the leftmost free cell of the back row, then the
## next row forward, and so on.
static func auto_place_bench(player: PlayerState) -> void:
	for unit in player.bench_units():
		for cell in own_cells():
			if player.unit_at(cell) == null:
				unit.cell = cell
				unit.placed = true
				break
