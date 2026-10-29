class_name ShieldStatus
extends Status
## A shield that absorbs damage, plus percent damage reduction, for a set time.
## Damage reduction applies first, then the shield absorbs what's left. When the
## shield is used up the reduction continues until time runs out.

const TINT := Color(0.6, 0.8, 1.0)   # sprite tint while active

var shield: float
var time_left: float


func _init(p_shield: float, p_duration: float) -> void:
	shield = p_shield
	time_left = p_duration


func on_applied(unit: BattleUnit) -> void:
	if unit.sprite != null:
		unit.sprite.self_modulate = TINT


func on_removed(unit: BattleUnit) -> void:
	if unit.sprite != null:
		unit.sprite.self_modulate = Color.WHITE


func get_shield(_unit: BattleUnit) -> float:
	return shield


func modify_incoming_damage(_unit: BattleUnit, damage: float) -> float:
	var absorbed := minf(shield, damage)
	shield -= absorbed
	return damage - absorbed


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)

func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false
