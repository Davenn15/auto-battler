class_name GateRules
extends RefCounted
## Shared bits for GATE.W(A): its colour, and which units count as "brought in" by it.

const COLOR := Color(0.95, 0.75, 0.05)   # deep yellow
const LIGHT := Color(1.0, 0.92, 0.5)
## Set on a unit brought back by GATE.W(A)'s revive; the value is that GATE.W(A)'s id.
const REVIVED_META := "gate_revived"


## True for a unit that didn't start the battle on the board: summons (anyone's) and
## revived allies.
static func is_newcomer(unit: BattleUnit) -> bool:
	return unit.is_summon or unit.has_meta(REVIVED_META)


## True for a unit `gate` brought into the fight: its Gatelings, or allies it revived.
static func is_follower(unit: BattleUnit, gate: BattleUnit) -> bool:
	var id := gate.get_instance_id()
	return unit.get_summoner_id() == id or unit.get_meta(REVIVED_META, 0) == id
