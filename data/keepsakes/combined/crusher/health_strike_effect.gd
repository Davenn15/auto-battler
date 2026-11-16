class_name HealthStrikeEffect
extends Passive
## Hit Effect: a follow-up hit for a share of the unit's own max health. It wracks
## whenever the attack it follows wracked.

@export var share: float = 0.04


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Heft.new(share))


class Heft extends Status:
	var share: float

	func _init(p_share: float) -> void:
		share = p_share

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return HeftHit.new(unit.get_credit_id(), unit.max_health * share, unit.get_attack_damage_type(),
				1.0 + unit.get_stat(Stats.Stat.WRACK_DAMAGE))

	func modify_swing_color(_unit: BattleUnit, _color: Color) -> Color:
		return Color(0.35, 1.0, 0.4)   # green sword


## The follow-up hit, its damage fixed when the attack is made.
class HeftHit extends HitEffect:
	var credit_id: int
	var damage: float
	var damage_type: int
	var wrack_multiplier: float

	func _init(p_credit_id: int, p_damage: float, p_type: int, p_wrack_multiplier: float) -> void:
		credit_id = p_credit_id
		damage = p_damage
		damage_type = p_type
		wrack_multiplier = p_wrack_multiplier

	func apply(target: BattleUnit, _dealt: float, wrack_level: int) -> void:
		if not target.alive:
			return   # the attack already finished it
		var dealt := target.take_damage(BattleUnit.damage_bonus(credit_id, target, damage * pow(wrack_multiplier, wrack_level)), wrack_level, damage_type)
		target.get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
