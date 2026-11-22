class_name ShieldStatus
extends Status
## A shield that absorbs damage, plus percent damage reduction, for a set time.
## Damage reduction applies first, then the shield absorbs what's left. When the
## shield is used up the reduction continues until time runs out.

const TINT := Color(0.6, 0.8, 1.0)   # sprite tint while active

var shield: float
var time_left: float
## Instance id of whoever gave it (BattleUnit.add_shield sets it).
var source_id := 0
## True for a shield a unit's own Gambit gave it: no Charge while it holds.
var locks_charge := false


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

## A shield from the unit's own Gambit blocks Charge until it breaks or runs out; any
## other shield never does.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return locks_charge and shield > 0.0


func is_own_shield(unit: BattleUnit) -> bool:
	return source_id != 0 and (source_id == unit.get_instance_id() or source_id == unit.get_credit_id())
