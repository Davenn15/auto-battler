class_name RunningNumber
extends Label
## One damage number for damage that keeps coming (beams, bleeds, Mono-Virus, burns): it
## sits above the unit, counts up as more damage lands, and once nothing has been added
## for a moment it drifts up and fades like a normal number. Made by
## BattleUnit.add_running_damage, one per effect per unit.

## Seconds without new damage before it fades.
const LINGER := 0.45
## How far above the first one each extra running number on the same unit sits (pixels),
## so a few at once stack instead of overlapping.
const SLOT_GAP := 20.0
const MAX_SLOTS := 4

var unit: BattleUnit
var total := 0.0
var slot := 0
## Seconds without new damage before it fades (longer for effects that hit in pulses).
var linger := LINGER
var _quiet := 0.0
var _fading := false
var _wrack := 0


func add(amount: float, color: Color, wrack_level: int) -> void:
	total += amount
	_quiet = 0.0
	_wrack = maxi(_wrack, wrack_level)
	text = str(roundi(total))
	add_theme_color_override("font_color", color)
	add_theme_font_size_override("font_size", unit._damage_font_size(total, _wrack))
	if _wrack > 0:
		BattleUnit.add_wrack_icon(self)   # marks that some of this damage wracked; follows the text as it grows


## True while it can still take more damage (not fading out yet).
func is_open() -> bool:
	return not _fading


func _process(delta: float) -> void:
	if _fading:
		return
	if is_instance_valid(unit) and unit.is_inside_tree():
		var centre := Vector2(0.0, BattleUnit.FLOAT_TEXT_BOTTOM - BattleUnit.FLOAT_TEXT_BOX.y / 2.0 - SLOT_GAP * (slot % MAX_SLOTS))
		global_position = unit.global_position + centre.rotated(BattleUnit.view_rotation) - BattleUnit.FLOAT_TEXT_BOX / 2.0
	_quiet += delta
	if _quiet >= linger or not is_instance_valid(unit):
		_fade()


func _fade() -> void:
	_fading = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", global_position + Vector2(0.0, -BattleUnit.FLOAT_RISE).rotated(BattleUnit.view_rotation), BattleUnit.FLOAT_TIME)
	tween.tween_property(self, "modulate:a", 0.0, BattleUnit.FLOAT_TIME)
	tween.chain().tween_callback(queue_free)
