class_name OverdriveStatus
extends Status
## Scour's Overdrive: extra Might and Celerity, but he burns a share of his max health every
## second while it lasts. The burn can kill him.

var time_left: float
var might_bonus: float
var celerity_bonus: float
var burn_per_second: float   # share of max health lost each second (0.04 = 4%)


func _init(p_duration: float, p_might: float, p_celerity: float, p_burn: float) -> void:
	time_left = p_duration
	might_bonus = p_might
	celerity_bonus = p_celerity
	burn_per_second = p_burn


func on_applied(unit: BattleUnit) -> void:
	KeepsakeVfx.set_glow(unit, "VfxOverdrive", OVERDRIVE_GLOW, 1.0)


func on_removed(unit: BattleUnit) -> void:
	KeepsakeVfx.clear(unit, "VfxOverdrive")


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	match stat:
		Stats.Stat.MIGHT:
			return value + might_bonus
		Stats.Stat.CELERITY:
			return value + celerity_bonus
	return value


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
		return
	unit.add_running_damage("self_burn", unit.take_warded_damage(unit.max_health * burn_per_second * delta), OverdriveStatus.OVERDRIVE_GLOW)


const OVERDRIVE_GLOW := Color(1.0, 0.35, 0.15)
