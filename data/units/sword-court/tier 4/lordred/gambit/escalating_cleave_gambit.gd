class_name EscalatingCleaveGambit
extends Gambit
## Cleaves the current target with a real attack that adds heavy bonus damage from the
## target's max health. Each cast makes the next one cost more charge and hit harder.

const CLEAVE_COLOR := Color(0.85, 0.15, 0.15)   # blood red

## Bonus damage = (Bonus Damage + Max Health Percent x target's max health) x escalation.
@export var bonus_damage: float = 100.0
@export_range(0.0, 1.0, 0.005) var max_health_percent: float = 0.12
## Each earlier cast this combat adds this share to the bonus (0.3 = +30% per cast).
@export var damage_growth: float = 0.3
## Each cast raises his max charge by this much for the rest of combat.
@export var charge_growth: float = 15.0
## When the cleave kills its target, the caster's charge fills right back up.
@export var refund_on_kill: bool = false

## Only casts once his target is within reach, so the cleave isn't wasted walking.
func can_use(caster: BattleUnit) -> bool:
	return _in_reach(caster, caster.target)


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var target = caster.target   # untyped: it may be freed while casting
	if not _in_reach(caster, target):
		return
	var tracker := _tracker(caster)
	var escalation := 1.0 + damage_growth * tracker.casts
	var bonus: float = (bonus_damage + max_health_percent * target.max_health) * escalation
	tracker.escalate(caster, charge_growth)   # the next cast costs more
	caster.show_float_text("Cleave ×%d" % tracker.casts, CLEAVE_COLOR)
	caster.attack_now(target, bonus)
	if refund_on_kill and not _alive(target):
		caster.fill_charge()

## The caster's escalation counter, made on the first cast.
func _tracker(caster: BattleUnit) -> EscalationStatus:
	for status in caster.statuses:
		if status is EscalationStatus:
			return status
	var tracker := EscalationStatus.new()
	caster.add_status(tracker)
	return tracker


func _in_reach(caster: BattleUnit, unit) -> bool:
	return _alive(unit) and caster.grid.get_distance(caster.cell, unit.cell) <= caster.attack_range


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive
