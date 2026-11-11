class_name GateRules
extends RefCounted
## Shared bits for GATE.W(A): its colour, and which units "didn't start there".

const COLOR := Color(0.95, 0.75, 0.05)   # deep yellow
const LIGHT := Color(1.0, 0.92, 0.5)
## Set on a unit brought back by GATE.W(A)'s revive.
const REVIVED_META := "gate_revived"


## True for a unit that didn't start the battle on the board: summons (anyone's) and
## revived allies.
static func is_newcomer(unit: BattleUnit) -> bool:
	return unit.is_summon or unit.has_meta(REVIVED_META)
