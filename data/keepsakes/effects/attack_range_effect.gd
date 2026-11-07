class_name AttackRangeEffect
extends Passive
## Extra attack range.

@export var bonus: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Reach.new(bonus))


class Reach extends Status:
	var bonus: int

	func _init(p_bonus: int) -> void:
		bonus = p_bonus

	func on_applied(unit: BattleUnit) -> void:
		unit.attack_range += bonus

	func on_removed(unit: BattleUnit) -> void:
		unit.attack_range -= bonus
