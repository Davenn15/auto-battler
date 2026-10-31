class_name SunderStrikeGambit
extends Gambit
## Strikes the caster's current target and lowers all of its wards for a while.
## Gambit damage doesn't wrack and doesn't build charge.

@export var damage: float = 120.0
## Extra damage per point of the caster's Might. Total damage = Damage + Might Scaling × Might.
@export var might_scaling: float = 1.0
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## How much each of the target's wards is lowered.
@export var ward_reduction: float = 30.0
## Seconds the wards stay lowered.
@export var ward_duration: float = 4.0
## Extra damage per point of the caster's Insight.
@export var insight_scaling: float = 0.0
## Extra damage as a fraction of the target's max health (0.05 = 5%).
@export_range(0.0, 1.0, 0.005) var max_health_percent: float = 0.0


## Only fires when her current target is alive and in attack range, so charge isn't wasted.
func can_use(caster: BattleUnit) -> bool:
	return _target_in_range(caster)


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	# The target may have moved or died during the Act time, so check again.
	if not _target_in_range(caster):
		return
	var target := caster.target

	# Wards drop first, so this strike already hits the lowered wards.
	_apply_ward_break(target)
	var hit_damage := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	hit_damage = Stats.scaled(hit_damage, insight_scaling, caster.get_stat(Stats.Stat.INSIGHT))
	hit_damage += max_health_percent * target.max_health
	var dealt := target.take_damage(hit_damage, false, damage_type)
	caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_instance_id(), dealt)


func _target_in_range(caster: BattleUnit) -> bool:
	var target := caster.target
	return is_instance_valid(target) and target.alive \
			and caster.grid.get_distance(caster.cell, target.cell) <= caster.attack_range


## Refreshes an existing ward break instead of stacking a second one.
func _apply_ward_break(target: BattleUnit) -> void:
	for status in target.statuses:
		if status is WardBreakStatus:
			status.refresh(ward_reduction, ward_duration)
			return
	target.add_status(WardBreakStatus.new(ward_reduction, ward_duration))
