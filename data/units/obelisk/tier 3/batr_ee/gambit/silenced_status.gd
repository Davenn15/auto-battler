class_name SilencedStatus
extends Status
## Silenced: can't cast its Gambit or gain Charge for a while. Crowd control, so units
## that resist it (MALLET) shake it off sooner, and immune units ignore it.

var time_left: float
var _label: Label


## Silences `target` for `duration` seconds, or refreshes a silence that's shorter.
static func silence(target: BattleUnit, duration: float) -> void:
	if target == null or not target.alive or duration <= 0.0:
		return
	if target.is_cc_immune():
		target.show_float_text("Immune", VoltageStatus.LIGHT)
		return
	duration *= target.crowd_control_multiplier()
	for status in target.statuses:
		if status is SilencedStatus:
			status.time_left = maxf(status.time_left, duration)
			return
	var silenced := SilencedStatus.new()
	silenced.time_left = duration
	target.add_status(silenced)


func on_applied(unit: BattleUnit) -> void:
	unit.show_float_text("Silenced", VoltageStatus.LIGHT)
	_label = Label.new()
	_label.text = "∅"
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", VoltageStatus.LIGHT)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.position = Vector2(-22, -40)
	_label.z_index = 15
	unit.add_child(_label)


func on_removed(_unit: BattleUnit) -> void:
	if is_instance_valid(_label):
		_label.queue_free()


func blocks_gambit(_unit: BattleUnit) -> bool:
	return true


func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return true


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
