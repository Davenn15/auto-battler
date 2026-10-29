class_name EmpowerStatus
extends Status
## Bonus damage on the unit's next few attacks. Holds its own state, so the Action
## resource (shared by every unit using it) stays stateless.

const TINT := Color(1.0, 0.55, 0.55)   # sprite tint while active
const PROJECTILE_COLOR := Color(1.0, 0.45, 0.75)   # pink

var bonus: float
var insight_scaling: float
var attacks_left: int


func _init(p_bonus: float, p_insight_scaling: float, p_attacks: int) -> void:
	bonus = p_bonus
	insight_scaling = p_insight_scaling
	attacks_left = p_attacks


func on_applied(unit: BattleUnit) -> void:
	if unit.sprite != null:
		unit.sprite.self_modulate = TINT


func on_removed(unit: BattleUnit) -> void:
	if unit.sprite != null:
		unit.sprite.self_modulate = Color.WHITE


func modify_outgoing_damage(unit: BattleUnit, damage: float) -> float:
	return damage + Stats.scaled(bonus, insight_scaling, unit.get_stat(Stats.Stat.INSIGHT))


func on_attack(unit: BattleUnit) -> void:
	attacks_left -= 1
	if attacks_left <= 0:
		unit.remove_status(self)


func modify_projectile_color(_unit: BattleUnit, _color: Color) -> Color:
	return PROJECTILE_COLOR
