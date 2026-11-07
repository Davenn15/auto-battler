class_name MarkHunterStatus
extends Status
## Von Carrow's side of the X: she keeps going after the marked enemy, and if it dies
## while the X is up, she gains a big shield.

var marked                 # untyped: the enemy may be freed when it dies
var mark: XMarkStatus
var time_left: float
var shield_amount: float
var shield_duration: float


func _init(p_marked: BattleUnit, p_mark: XMarkStatus, p_duration: float, p_shield: float, p_shield_duration: float) -> void:
	marked = p_marked
	mark = p_mark
	time_left = p_duration
	shield_amount = p_shield
	shield_duration = p_shield_duration


## The X lasts a while; it shouldn't stop her charging the whole time.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func modify_target_choice(unit: BattleUnit, choice: BattleUnit, exclude: BattleUnit) -> BattleUnit:
	if is_instance_valid(marked) and marked != exclude and unit._is_valid_target(marked):
		return marked
	return choice


func tick(unit: BattleUnit, delta: float) -> void:
	if not is_instance_valid(marked) or not marked.alive:
		unit.add_shield(shield_amount, shield_duration, unit.get_instance_id())
		unit.show_float_text("Marked kill", Color(0.9, 0.1, 0.1))
		unit.remove_status(self)
		return
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)


## Recasting replaces this; take the old X off its enemy too.
func on_removed(_unit: BattleUnit) -> void:
	if is_instance_valid(marked) and marked.statuses.has(mark):
		marked.remove_status(mark)
