class_name SilenceStatus
extends Status
## Can't gain charge or cast a Gambit for a while. Charge already built up is kept.

var time_left: float


func _init(p_duration: float) -> void:
	time_left = p_duration


func on_applied(unit: BattleUnit) -> void:
	unit.show_float_text("Silenced", Color(0.75, 0.6, 1.0))


func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return true


func blocks_gambit(_unit: BattleUnit) -> bool:
	return true


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
