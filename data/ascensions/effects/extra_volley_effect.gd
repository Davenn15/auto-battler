class_name ExtraVolleyEffect
extends Passive
## Vestibule's hero Ascension: whenever it fires a group of projectiles with its Gambit (the
## base stun bolts, or B's Gift Shards), it fires Extra more. Not every projectile doubles:
## each group gets Extra added once. The Gambits ask ExtraVolleyEffect.extra_on(caster).

@export var extra: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	var status := VolleyStatus.new()
	status.effect = self
	unit.add_status(status)


## How many extra projectiles each of `unit`'s Gambit volleys gets (0 without it).
static func extra_on(unit: BattleUnit) -> int:
	var total := 0
	for status in unit.statuses:
		if status is VolleyStatus:
			total += status.effect.extra
	return total


class VolleyStatus extends Status:
	var effect: ExtraVolleyEffect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false
