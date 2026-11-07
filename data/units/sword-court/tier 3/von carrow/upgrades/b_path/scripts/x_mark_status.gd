class_name XMarkStatus
extends Status
## Von Carrow's X: shows a big red X on the unit and can cut its wards by a share.

var time_left: float
var ward_cut: float   # 0.5 = wards are halved
var _label: Label


func _init(p_duration: float, p_ward_cut: float) -> void:
	time_left = p_duration
	ward_cut = p_ward_cut


func on_applied(unit: BattleUnit) -> void:
	_label = Label.new()
	_label.text = "X"
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.position = Vector2(-9, -26)   # over the unit's body
	_label.z_index = 15
	unit.add_child(_label)


func on_removed(_unit: BattleUnit) -> void:
	if is_instance_valid(_label):
		_label.queue_free()


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)


## A share, so it runs after every flat ward change.
func modify_final_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	match stat:
		Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD:
			return value * (1.0 - ward_cut)
	return value
