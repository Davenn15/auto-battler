class_name CombatTimer
extends Label
## Counts down the time left until overtime, at the top centre of the screen. Once
## overtime starts, it says OVERTIME in big red letters instead.

const NORMAL_SIZE := 20
const OVERTIME_SIZE := 34
const NORMAL_COLOR := Color.WHITE
const OVERTIME_COLOR := Color(0.95, 0.15, 0.1)

var _manager: BattleManager
var _showing_overtime := false


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 5)
	_set_overtime_look(false)


func _process(_delta: float) -> void:
	if not is_instance_valid(_manager):
		_manager = get_tree().get_first_node_in_group("battle_manager") as BattleManager
		if _manager == null:
			text = ""
			return
	if _manager.in_overtime != _showing_overtime:
		_set_overtime_look(_manager.in_overtime)
	if _showing_overtime:
		return
	# Counts down to overtime. With overtime turned off (0), it counts up instead.
	var seconds := floori(_manager.combat_time)
	if _manager.overtime_after > 0.0:
		seconds = ceili(maxf(_manager.overtime_after - _manager.combat_time, 0.0))
	text = "%d:%02d" % [floori(seconds / 60.0), seconds % 60]


func _set_overtime_look(overtime: bool) -> void:
	_showing_overtime = overtime
	add_theme_font_size_override("font_size", OVERTIME_SIZE if overtime else NORMAL_SIZE)
	add_theme_color_override("font_color", OVERTIME_COLOR if overtime else NORMAL_COLOR)
	if overtime:
		text = "OVERTIME"
		# A quick pop as it appears.
		pivot_offset = size / 2.0
		scale = Vector2.ONE * 1.4
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
