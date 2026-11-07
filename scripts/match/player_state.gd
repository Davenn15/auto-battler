class_name PlayerState
extends RefCounted
## Everything one player has during a match: health, money, army, items and shop.

var player_name := "Player"
var is_ai := false
var faction := "Sword Court"

var hp: int = MatchRules.START_HP
var aura: int = MatchRules.START_AURA
var aura_received: int = MatchRules.START_AURA   # counts toward MatchRules.MAX_AURA_RECEIVED
var reserve: int = MatchRules.START_RESERVE

var units: Array[ArmyUnit] = []
var inventory: Array[Keepsake] = []   # Shards and keepsakes not on a unit

var unit_offers: Array[UnitData] = []   # the shop; a bought slot is removed
var shard_offers: Array[Keepsake] = []
var reroll_cost: int = MatchRules.REROLL_START
## Keeps this shop for the next planning phase instead of a fresh one (then unlocks).
var shop_locked := false

## The army as it was when this player last fought: what the other player gets to see
## (and what the computer opponent plans against). Empty before the first combat.
var last_fielded: Array[ArmyUnit] = []
var last_fielded_round := 0


func is_alive() -> bool:
	return hp > 0


func find_unit(data: UnitData) -> ArmyUnit:
	for unit in units:
		if unit.data == data:
			return unit
	return null


func board_units() -> Array[ArmyUnit]:
	return units.filter(func(u): return u.placed)


func bench_units() -> Array[ArmyUnit]:
	return units.filter(func(u): return not u.placed)


func unit_at(cell: Vector2i) -> ArmyUnit:
	for unit in units:
		if unit.placed and unit.cell == cell:
			return unit
	return null


## Aura spent on the whole army.
func army_aura() -> int:
	var total := 0
	for unit in units:
		total += unit.aura_value()
	return total


## A full copy, for the computer opponent to try out plans on without touching the real one.
func copy() -> PlayerState:
	var other := PlayerState.new()
	other.player_name = player_name
	other.is_ai = is_ai
	other.faction = faction
	other.hp = hp
	other.aura = aura
	other.aura_received = aura_received
	other.reserve = reserve
	other.units = ArmyUnit.copy_army(units)
	other.inventory = inventory.duplicate()
	other.unit_offers = unit_offers.duplicate()
	other.shard_offers = shard_offers.duplicate()
	other.reroll_cost = reroll_cost
	other.shop_locked = shop_locked
	other.last_fielded = ArmyUnit.copy_army(last_fielded)
	other.last_fielded_round = last_fielded_round
	return other


## Takes on the army, items, money and shop of `other` (a plan the computer chose).
func adopt(other: PlayerState) -> void:
	aura = other.aura
	reserve = other.reserve
	units = other.units
	inventory = other.inventory
	unit_offers = other.unit_offers
	shard_offers = other.shard_offers
	reroll_cost = other.reroll_cost
