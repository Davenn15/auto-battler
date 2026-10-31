class_name Economy
extends RefCounted
## Prices and value formulas. Aura buys and upgrades units; Reserve buys items and
## everything else. A team's ARV (Aura + Reserve value) is a rough measure of its strength.

## Aura cost for each tier: [buy, first upgrade, second upgrade].
const TIER_AURA_COSTS := {
	1: [2, 1, 1],
	2: [4, 2, 2],
	3: [6, 3, 3],
	4: [8, 4, 4],
}
const MAX_UPGRADE_LEVEL := 2


## Total Aura spent on a unit of this tier at this upgrade level (0 = not upgraded).
static func unit_aura_value(tier: int, upgrade_level: int) -> int:
	var costs: Array = TIER_AURA_COSTS.get(tier, [])
	var total := 0
	for i in mini(upgrade_level + 1, costs.size()):
		total += costs[i]
	return total


## A team's Aura and Reserve value, summed over the given units.
static func team_value(units: Array, team: int) -> Dictionary:
	var aura := 0
	var reserve := 0
	for node in units:
		var unit := node as BattleUnit
		if unit == null or unit.team != team:
			continue
		aura += unit.get_aura_value()
		reserve += unit.get_reserve_value()
	return {"aura": aura, "reserve": reserve, "total": aura + reserve}
