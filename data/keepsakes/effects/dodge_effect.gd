class_name DodgeEffect
extends Passive
## Extra dodge chance.

@export_range(0.0, 1.0, 0.01) var chance: float = 0.1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Nimble.new(chance))


class Nimble extends Status:
	var chance: float

	func _init(p_chance: float) -> void:
		chance = p_chance

	func modify_dodge_chance(_unit: BattleUnit, value: float) -> float:
		return value + chance
