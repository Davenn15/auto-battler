class_name ParryStanceStatus
extends Status
## Extra wards and a chance to send incoming projectiles back, for a while.

const PARRY_COLOR := Color(0.85, 0.85, 0.95)

var time_left: float
var ward_bonus: float
var celerity_bonus: float
var reflect_chance: float
var reflect_wrack_bonus: float


func _init(p_duration: float, p_ward_bonus: float, p_celerity_bonus: float, p_reflect_chance: float, p_reflect_wrack_bonus: float) -> void:
	time_left = p_duration
	ward_bonus = p_ward_bonus
	celerity_bonus = p_celerity_bonus
	reflect_chance = p_reflect_chance
	reflect_wrack_bonus = p_reflect_wrack_bonus


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat in [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]:
		return value + ward_bonus
	if stat == Stats.Stat.CELERITY:
		return value + celerity_bonus
	return value


func try_reflect(unit: BattleUnit, projectile: Projectile) -> bool:
	if CombatRng.randf() >= reflect_chance:
		return false
	var wrack_chance := unit.get_stat(Stats.Stat.WRACK_CHANCE) + reflect_wrack_bonus
	if not projectile.reflect(unit, wrack_chance):
		return false
	unit.show_float_text("Parry", PARRY_COLOR)
	return true
