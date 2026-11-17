class_name ReloadOnGainStatus
extends Status
## Whenever the unit gains permanent stats, its pistol loads a shot for its next attack.

const RELOAD_COLOR := Color(1.0, 0.85, 0.4)


func on_permanent_stats_gained(unit: BattleUnit, _gains: Dictionary) -> void:
	for status in unit.statuses:
		if status is PistolStatus:
			status.load_shot(unit)
			unit.show_float_text("Reload", RELOAD_COLOR)
			return
