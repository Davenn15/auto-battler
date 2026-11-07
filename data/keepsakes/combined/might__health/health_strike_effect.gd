class_name HealthStrikeEffect
extends Passive
## The unit's attacks deal extra damage equal to a share of its own max health.

@export var share: float = 0.04


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Heft.new(share))


class Heft extends Status:
	var share: float

	func _init(p_share: float) -> void:
		share = p_share

	func modify_outgoing_damage(unit: BattleUnit, damage: float) -> float:
		return damage + unit.max_health * share

	func modify_swing_color(_unit: BattleUnit, _color: Color) -> Color:
		return Color(0.35, 1.0, 0.4)   # green sword
