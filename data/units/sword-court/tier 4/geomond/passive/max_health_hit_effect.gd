class_name MaxHealthHitEffect
extends HitEffect
## A follow-up hit for a share of the target's max health. It wracks whenever the attack
## it follows wracked, and a dodged attack has none.

var source_id: int
var percent: float
var damage_type: int
var wrack_multiplier: float


func _init(p_source_id: int, p_percent: float, p_type: int, p_wrack_multiplier: float) -> void:
	source_id = p_source_id
	percent = p_percent
	damage_type = p_type
	wrack_multiplier = p_wrack_multiplier


func apply(target: BattleUnit, _dealt: float, wrack_level: int) -> void:
	if not target.alive:
		return   # the attack already finished it
	var amount := percent * target.max_health * pow(wrack_multiplier, wrack_level)
	var dealt := target.take_damage(amount, wrack_level, damage_type)
	target.get_tree().call_group("damage_tracker", "record_damage", source_id, dealt)
