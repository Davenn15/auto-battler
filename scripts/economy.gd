class_name Economy
extends RefCounted
## Prices and value formulas. Aura buys and upgrades units; Reserve buys items and
## everything else. A team's ARV is a rough measure of its strength: an ARV 48 team has
## spent 48 Aura on units and 48 Reserve on items.

## TESTING (2026-11-11): the tier rework. true = the new numbers: these Aura costs, smaller
## tier bonuses and bigger level 2 growth (Stats), and more match Aura (MatchRules).
## false = the old numbers everywhere. The balance sim's --old-economy flag sets it false.
## To undo the rework for good, set this to false (or delete the NEW_ tables and the switch).
static var tier_rework := true

## Aura cost for each tier: [buy, first upgrade, second upgrade].
const NEW_TIER_AURA_COSTS := {
	1: [4, 2, 4],
	2: [6, 3, 6],
	3: [8, 4, 8],
	4: [10, 5, 10],
}
const OLD_TIER_AURA_COSTS := {
	1: [2, 1, 1],
	2: [4, 2, 2],
	3: [6, 3, 3],
	4: [8, 4, 4],
}
const MAX_UPGRADE_LEVEL := 2


## [buy, first upgrade, second upgrade] Aura costs for a tier.
static func tier_aura_costs(tier: int) -> Array:
	return (NEW_TIER_AURA_COSTS if tier_rework else OLD_TIER_AURA_COSTS).get(tier, [])


## Total Aura spent on a unit of this tier at this upgrade level (0 = not upgraded).
static func unit_aura_value(tier: int, upgrade_level: int) -> int:
	var costs: Array = tier_aura_costs(tier)
	var total := 0
	for i in mini(upgrade_level + 1, costs.size()):
		total += costs[i]
	return total


## A team's Aura and Reserve value, summed over the given units. Its ARV ("total") is the
## larger of the two: Aura and Reserve are each meant to match the ARV, and Reserve can fall
## a little short because items only come in whole Shards.
static func team_value(units: Array, team: int) -> Dictionary:
	var aura := 0
	var reserve := 0
	for node in units:
		var unit := node as BattleUnit
		if unit == null or unit.team != team:
			continue
		aura += unit.get_aura_value()
		reserve += unit.get_reserve_value()
	return {"aura": aura, "reserve": reserve, "total": maxi(aura, reserve)}
