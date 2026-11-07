class_name MatchRules
extends RefCounted
## The rules of a match, as numbers and small functions: money, the shop, items, the board
## and damage. Both the screen and the computer opponent go through these, so they always
## play by the same rules.

const START_HP := 64
const START_AURA := 6
const START_RESERVE := 10
## The most Aura a player is ever given in a match, counting the starting Aura.
const MAX_AURA_RECEIVED := 48

const UNIT_OFFERS := 3
const SHARD_OFFERS := 3
const SHARD_COST := 3
const SHARD_SELL := 2
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
const KEEPSAKES_DIR := "res://data/keepsakes"

static var _roster: Array[UnitData] = []
static var _pools: Dictionary = {}


static func roster() -> Array[UnitData]:
	if _roster.is_empty():
		_roster = RandomTeams.load_roster(UNITS_DIR)
	return _roster


static func shards() -> Array:
	return _keepsake_pools()["shards"]


static func keepsakes() -> Array:
	return _keepsake_pools()["keepsakes"]


static func _keepsake_pools() -> Dictionary:
	if _pools.is_empty():
		_pools = RandomTeams.load_keepsakes(KEEPSAKES_DIR)
	return _pools


# ---------- Rounds and money ----------

## Aura and Reserve each player gets after a player combat in round `round_number`.
static func combat_income(round_number: int) -> int:
	return round_number


## Pays both kinds of income. Aura stops once the player has been given MAX_AURA_RECEIVED.
static func pay_income(player: PlayerState, round_number: int) -> Dictionary:
	var income := combat_income(round_number)
	var aura := clampi(income, 0, MAX_AURA_RECEIVED - player.aura_received)
	player.aura += aura
	player.aura_received += aura
	player.reserve += income
	return {"aura": aura, "reserve": income}


## Damage to the loser of a player combat in round `round_number`, when the winner has
## `surviving_aura` Aura of units left (upgrades count; summons and keepsakes don't).
static func loss_damage(round_number: int, surviving_aura: int) -> int:
	return round_number + surviving_aura / 2


## Draws: each player takes half of what they'd take for losing, rounded down.
static func draw_damage(round_number: int, enemy_surviving_aura: int) -> int:
	return loss_damage(round_number, enemy_surviving_aura) / 2


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


static func buff_cost(tier: int, buffs_bought: int) -> int:
	return 2 * tier * (buffs_bought + 1)


## What buying `data` from the shop means for this player:
## {kind: "buy" | "upgrade" | "buff", aura: cost, reserve: cost}.
static func offer_info(player: PlayerState, data: UnitData) -> Dictionary:
	var owned := player.find_unit(data)
	var costs: Array = Economy.TIER_AURA_COSTS[data.tier]
	if owned == null:
		return {"kind": "buy", "aura": costs[0], "reserve": 0}
	if not owned.is_maxed():
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


# ---------- The shop ----------

## Fills the shop for a new planning phase and resets the reroll price. A locked shop is
## kept as it was left (bought slots stay empty) instead, and the lock comes off.
static func start_planning(player: PlayerState, combat_number: int) -> void:
	player.reroll_cost = REROLL_START
	if player.shop_locked:
		player.shop_locked = false
		return
	roll_unit_offers(player, combat_number)
	roll_shard_offers(player)


static func tier_unlocked(tier: int, combat_number: int) -> bool:
	return combat_number >= TIER_FIRST_COMBAT.get(tier, 1)


## Three different units from the tiers unlocked for `combat_number`.
static func roll_unit_offers(player: PlayerState, combat_number: int) -> void:
	var pool := roster().filter(func(d): return tier_unlocked(d.tier, combat_number))
	pool.shuffle()
	player.unit_offers.assign(pool.slice(0, UNIT_OFFERS))


## Three different Shards.
static func roll_shard_offers(player: PlayerState) -> void:
	var pool := shards().duplicate()
	pool.shuffle()
	player.shard_offers.assign(pool.slice(0, SHARD_OFFERS))


## Rerolls the units and the Shards together. The price goes up each time.
static func reroll(player: PlayerState, combat_number: int) -> bool:
	if player.reserve < player.reroll_cost:
		return false
	player.reserve -= player.reroll_cost
	player.reroll_cost += REROLL_STEP
	roll_unit_offers(player, combat_number)
	roll_shard_offers(player)
	return true


static func buy_shard_offer(player: PlayerState, slot: int) -> bool:
	if slot < 0 or slot >= player.shard_offers.size() or player.reserve < SHARD_COST:
		return false
	player.reserve -= SHARD_COST
	player.inventory.append(player.shard_offers[slot])
	player.shard_offers.remove_at(slot)
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
	for r in range(GRID_ROWS - 1, GRID_ROWS / 2 - 1, -1):
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
