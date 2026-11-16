class_name ShieldedRegenEffect
extends Passive
## An Ascension effect (Aegis Mending): the unit has extra health regen while it has a
## shield.

## Health per second while shielded.
@export var regen: float = 15.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ShieldedRegenStatus.new(regen))


class ShieldedRegenStatus extends Status:
	var regen: float

	func _init(p_regen: float) -> void:
		regen = p_regen

	func modify_health_regen(unit: BattleUnit, value: float) -> float:
		return value + regen if unit.get_shield() > 0.0 else value
