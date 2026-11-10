class_name TargetGuardPassive
extends Passive
## Grouser B2: he takes less damage from the enemy he's currently targeting.

## Share of that enemy's damage he ignores (0.25 = 25% less).
@export_range(0.0, 1.0, 0.05) var reduction: float = 0.25


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GuardStatus.new(reduction))


class GuardStatus extends Status:
	var reduction: float

	func _init(p_reduction: float) -> void:
		reduction = p_reduction

	func modify_incoming_damage(unit: BattleUnit, amount: float) -> float:
		if unit.incoming_attacker != null and unit.incoming_attacker == unit.target:
			return amount * (1.0 - reduction)
		return amount
