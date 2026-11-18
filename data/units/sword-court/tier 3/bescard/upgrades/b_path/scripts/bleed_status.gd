class_name BleedStatus
extends Status
## Deals Pure Damage over time (skips wards). Each one is separate, so bleeds stack.
## Only Obelisk's bleeds use this now (Glaive B2, Slim Gateling; to be removed); Sword
## Court's use the Bleed pool (see Bleed).

var source_id: int        # who the damage meter credits
var damage_per_second: float
var time_left: float


func _init(p_source_id: int, p_damage_per_second: float, p_duration: float) -> void:
	source_id = p_source_id
	damage_per_second = p_damage_per_second
	time_left = p_duration


func tick(unit: BattleUnit, delta: float) -> void:
	if not unit.active:
		return
	var step := minf(delta, time_left)
	time_left -= delta
	var dealt := unit.take_warded_damage(BattleUnit.damage_bonus(source_id, unit, damage_per_second * step), false, Stats.DamageType.PURE)
	unit.add_running_damage("bleed", dealt, Stats.damage_color(Stats.DamageType.PURE))
	unit.get_tree().call_group("damage_tracker", "record_damage", source_id, dealt)
	if time_left <= 0.0:
		unit.remove_status(self)
