class_name ReloadOnGainStatus
extends Status
## Whenever the unit gains permanent stats, its pistol loads a shot for its next attack.

const RELOAD_COLOR := Color(1.0, 0.85, 0.4)


func on_status_added(unit: BattleUnit, added: Status) -> void:
	if not added.is_permanent_stat_gain():
		return
	for status in unit.statuses:
		if status is PistolStatus:
			status.load_shot(unit)
			unit.show_float_text("Reload", RELOAD_COLOR)
			return
