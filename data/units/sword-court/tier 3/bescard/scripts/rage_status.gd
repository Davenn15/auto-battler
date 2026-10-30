class_name RageStatus
extends Status
## Bonus Might and Celerity, plus lifesteal on attacks, for a set time.

const TINT := Color(1.0, 0.45, 0.35)   # sprite tint while active

var time_left: float
var might: float
var celerity: float
var lifesteal: float   # fraction of attack damage dealt that heals the unit


func _init(p_duration: float, p_might: float, p_celerity: float, p_lifesteal: float) -> void:
	time_left = p_duration
	might = p_might
	celerity = p_celerity
	lifesteal = p_lifesteal


func on_applied(unit: BattleUnit) -> void:
	if unit.sprite != null:
		unit.sprite.self_modulate = TINT


func on_removed(unit: BattleUnit) -> void:
	if unit.sprite != null:
		unit.sprite.self_modulate = Color.WHITE


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat == Stats.Stat.MIGHT:
		return value + might
	if stat == Stats.Stat.CELERITY:
		return value + celerity
	return value


func on_attack_hit(unit: BattleUnit, _target: BattleUnit, dealt: float) -> void:
	unit.heal(dealt * lifesteal)


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
