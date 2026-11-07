class_name SleepStatus
extends Status
## Asleep: stunned until it wears off, or until the unit has taken a set amount of
## damage. Can also lower its wards while it sleeps.

var time_left: float
var wake_at: float    # total damage that wakes it
var ward_cut: float   # 0.4 = wards are 40% lower while asleep
var _taken: float = 0.0
var _label: Label


func _init(p_duration: float, p_wake_at: float, p_ward_cut: float) -> void:
	time_left = p_duration
	wake_at = p_wake_at
	ward_cut = p_ward_cut


func on_applied(unit: BattleUnit) -> void:
	unit.stun(time_left)
	_label = Label.new()
	_label.text = "Zz"
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(0.935, 0.441, 0.66, 1.0))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.position = Vector2(10, -40)
	_label.z_index = 15
	unit.add_child(_label)


func on_removed(_unit: BattleUnit) -> void:
	if is_instance_valid(_label):
		_label.queue_free()


func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
	_taken += damage
	if _taken >= wake_at:
		unit.clear_stun()
		unit.show_float_text("Awake!", Color(1.0, 0.9, 0.6))
		unit.remove_status(self)
	return damage


func modify_final_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	match stat:
		Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD:
			return value * (1.0 - ward_cut)
	return value


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)   # the stun runs out at the same moment
