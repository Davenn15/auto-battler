class_name SnipGambit
extends Gambit
## Grouser snips his target with his claw, Snips times in quick succession. Each snip is an
## attack (it can wrack, shreds wards, triggers on-hit effects) with bonus damage equal to a
## share of the target's max health.

@export var snips: int = 2
## Seconds between snips.
@export var interval: float = 0.25
## Bonus damage per snip, as a share of the target's max health (0.06 = 6%).
@export_range(0.0, 0.5, 0.01) var max_health_damage: float = 0.06


func can_use(caster: BattleUnit) -> bool:
	return _target(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var target := _target(caster)
	if target == null:
		return
	caster.show_float_text("Snip", WardShiftStatus.COLOR)
	for i in snips:
		if i > 0:
			await caster.get_tree().create_timer(interval, false, true).timeout
		if not is_instance_valid(caster) or not caster.alive or not is_instance_valid(target) or not target.alive:
			return
		KeepsakeVfx.claw_snip(target)
		caster.attack_now(target, target.max_health * max_health_damage)


## His current target if it's alive and within his attack range.
func _target(caster: BattleUnit) -> BattleUnit:
	var target := caster.target
	if is_instance_valid(target) and target.alive and target.is_targetable() \
			and caster.grid.get_distance(caster.cell, target.cell) <= caster.attack_range:
		return target
	return null
