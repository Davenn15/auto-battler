class_name ShieldReductionStatus
extends Status
## Reduces incoming damage by a percentage while the unit has a shield.
## Attached by a passive at battle start, so it sits ahead of any shield status in the
## unit's list and the reduction is applied before the shield absorbs damage.

var reduction: float   # 0.1 = 10% less damage taken


func _init(p_reduction: float) -> void:
	reduction = p_reduction


func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
	if unit.get_shield() > 0.0:
		return damage * (1.0 - reduction)
	return damage
