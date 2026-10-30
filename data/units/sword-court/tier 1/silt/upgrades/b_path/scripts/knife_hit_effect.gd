class_name KnifeHitEffect
extends HitEffect
## A knife strike that follows an attack. It wracks whenever the attack it follows wracked.

var silt_id: int
var damage: float
var damage_type: int
var wrack_multiplier: float


func _init(p_silt_id: int, p_damage: float, p_type: int, p_wrack_multiplier: float) -> void:
	silt_id = p_silt_id
	damage = p_damage
	damage_type = p_type
	wrack_multiplier = p_wrack_multiplier


func apply(target: BattleUnit, _dealt: float, is_wrack: bool) -> void:
	if not target.alive:
		return   # the attack already finished it
	var amount := damage * wrack_multiplier if is_wrack else damage
	var dealt := target.take_damage(amount, is_wrack, damage_type)
	target.get_tree().call_group("damage_tracker", "record_damage", silt_id, dealt)
