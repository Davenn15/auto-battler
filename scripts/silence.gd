class_name Silence
extends Status
## The Silence keyword: a Silenced unit can't cast its Gambit or gain Charge for a while
## (Charge it already has is kept). It's crowd control: Immovability shortens it, 100 or
## more ignores it, and an item that lets control effects wrack lengthens it. Silencing a
## unit that's already Silenced keeps whichever silence is longer, and counts as a new
## silence (Codger's passive watches for it). Prancelot's Silencing Note and BATR.EE's A2
## Volts both use it.

const COLOR := Color(0.75, 0.6, 1.0)   # violet

var time_left: float
var _mark: Label


## Silences `target` for `duration` seconds. `source` (optional) is who did it: its items
## may wrack the silence longer. Returns the Silence on the target (a refreshed one if it
## was already Silenced), or null if it didn't land.
static func apply(target: BattleUnit, duration: float, source = null) -> Silence:
	if target == null or not target.alive or duration <= 0.0:
		return null
	if is_instance_valid(source):
		duration *= source.wrack_effect_multiplier(Stats.EffectKind.CONTROL, false, target)
	if target.is_cc_immune():
		target.show_float_text("Immune", BattleUnit.DODGE_COLOR)
		return null
	duration *= target.crowd_control_multiplier()
	if duration <= 0.0:
		return null
	for status in target.statuses:
		if status is Silence:
			status.time_left = maxf(status.time_left, duration)
			target.show_float_text("Silenced", COLOR)
			target.crowd_controlled.emit(target)   # silenced again: counts as a new silence
			return status
	var silence := Silence.new()
	silence.time_left = duration
	target.add_status(silence)
	return silence


## True while `unit` is Silenced.
static func is_silenced(unit: BattleUnit) -> bool:
	return unit.statuses.any(func(s): return s is Silence)


func on_applied(unit: BattleUnit) -> void:
	unit.show_float_text("Silenced", COLOR)
	unit.crowd_controlled.emit(unit)
	if not KeepsakeVfx.enabled():
		return
	_mark = Label.new()
	_mark.text = "∅"
	_mark.add_theme_font_size_override("font_size", 16)
	_mark.add_theme_color_override("font_color", COLOR)
	_mark.add_theme_color_override("font_outline_color", Color.BLACK)
	_mark.add_theme_constant_override("outline_size", 3)
	_mark.position = Vector2(-22, -40)
	_mark.z_index = 15
	unit.add_child(_mark)


func on_removed(_unit: BattleUnit) -> void:
	if is_instance_valid(_mark):
		_mark.queue_free()


func blocks_gambit(_unit: BattleUnit) -> bool:
	return true


## Blocks Charge for as long as it lasts, even though it never comes from the unit's own
## Gambit.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return true


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
