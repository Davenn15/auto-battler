class_name PassiveSwapEffect
extends Passive
## An Ascension effect (Brothers in Arms): when both units of the Pair are fighting on the
## same side, each also gains the other's base passives for the combat (they show on its
## Abilities tab too).

## The two units that share their passives.
@export var pair: Array[UnitData] = []


func on_battle_start(unit: BattleUnit) -> void:
	if pair.size() != 2 or not pair.has(unit.data):
		return
	var partner_data: UnitData = pair[1] if unit.data == pair[0] else pair[0]
	if not _fielded(unit, partner_data):
		return
	for passive in partner_data.passives:
		if passive == null or unit.passives.has(passive):
			continue
		unit.passives.append(passive)   # its own copy of the list, so the info panel lists it
		passive.on_battle_start(unit)


## True if a living unit of `data` (not a summon) is fighting on `unit`'s side.
static func _fielded(unit: BattleUnit, data: UnitData) -> bool:
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other != null and other != unit and other.alive and other.team == unit.team \
				and not other.is_summon and other.data == data:
			return true
	return false
