class_name RallyPassive
extends Passive
## Allies within range get bonus Celerity for as long as they stay in range.

## Celerity granted to each ally in range.
@export var celerity_bonus: float = 20.0
## Range in hex cells. The Rally gambit uses this same range.
@export var range_cells: int = 2
## Whether Lunck benefits from his own aura.
@export var include_self: bool = false


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(RallyAuraStatus.new(celerity_bonus, range_cells, include_self))
	KeepsakeVfx.rally_aura(unit, aura_range(unit), aura_gives_insight(unit))


## How far `unit`'s Rally reaches, counting range upgrades, or -1 if it has no Rally.
## Read from its passives, so it works before a battle starts too (the planning board).
static func aura_range(unit: BattleUnit) -> int:
	var reach := -1
	for passive in unit.passives:
		if passive is RallyPassive:
			reach = passive.range_cells
	if reach < 0:
		return -1
	for passive in unit.passives:
		if passive is RallyBoostPassive:
			reach += passive.range_bonus
	return reach


## True if an upgrade makes `unit`'s Rally give Insight too (his aura then shows blue).
static func aura_gives_insight(unit: BattleUnit) -> bool:
	for passive in unit.passives:
		if passive is RallyBoostPassive and passive.insight_bonus > 0.0:
			return true
	return false
