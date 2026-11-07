class_name OvertimeStatus
extends Status
## Overtime: extra Celerity (optionally rising the longer it lasts) and less healing and
## shielding received, so long fights reach a finish.

const OVERTIME_COLOR := Color(1.0, 0.5, 0.2)

var celerity_bonus: float
var celerity_per_second: float
var healing_multiplier: float
var shield_multiplier: float
var _elapsed: float = 0.0


func _init(p_celerity_bonus: float, p_celerity_per_second: float,
		p_healing_multiplier: float, p_shield_multiplier: float) -> void:
	celerity_bonus = p_celerity_bonus
	celerity_per_second = p_celerity_per_second
	healing_multiplier = p_healing_multiplier
	shield_multiplier = p_shield_multiplier


func on_applied(unit: BattleUnit) -> void:
	unit.show_float_text("Overtime", OVERTIME_COLOR)


func tick(unit: BattleUnit, delta: float) -> void:
	if unit.active:
		_elapsed += delta


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat == Stats.Stat.CELERITY:
		return value + celerity_bonus + celerity_per_second * _elapsed
	return value


func modify_healing_received(_unit: BattleUnit, amount: float) -> float:
	return amount * healing_multiplier


func modify_shield_received(_unit: BattleUnit, amount: float) -> float:
	return amount * shield_multiplier
