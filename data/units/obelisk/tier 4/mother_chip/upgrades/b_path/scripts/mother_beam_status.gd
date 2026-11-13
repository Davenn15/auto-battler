class_name MotherBeamStatus
extends BeamStatus
## MOTHER-CHIP's B beam: Scour's continuous beam (BeamStatus) in bluish purple, dealing
## more the lower its target's health, with every Chip adding a thinner beam of its own at
## the same target (each Chip Share of the beam's damage, from ChipPassive).

var execute_bonus := 1.0


## MOTHER-CHIP's beam, or null.
static func of(unit: BattleUnit) -> MotherBeamStatus:
	if unit == null:
		return null
	for status in unit.statuses:
		if status is MotherBeamStatus:
			return status
	return null


## The enemy the beam is dealing damage to right now, or null (for the Chips' beams).
func firing_at():
	if _charging > 0.0 or not _alive(_target):
		return null
	return _target


func damage_multiplier(_unit: BattleUnit, enemy: BattleUnit) -> float:
	var missing := 1.0 - clampf(enemy.health / maxf(enemy.max_health, 1.0), 0.0, 1.0)
	return 1.0 + execute_bonus * missing


func beam_color(_unit: BattleUnit) -> Color:
	return ChipPassive.COLOR


## Each tick, the Chips' beams hit the same target too.
func _fire_tick(unit: BattleUnit, enemy: BattleUnit, share: float) -> void:
	super(unit, enemy, share)
	var chips := ChipPassive.of(unit)
	if chips == null or chips.chips <= 0 or not _alive(enemy):
		return
	var base := Stats.attack_damage(unit.get_stat(Stats.Stat.MIGHT)) * damage_multiplier(unit, enemy)
	var hit := base * share * chips.passive.chip_share * chips.chips
	var dealt := enemy.take_damage(hit, 0, unit.get_attack_damage_type(), unit.ignores_wards(), unit, false)
	unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), dealt)
	_dealt += dealt
	enemy.add_running_damage("beam_%d" % unit.get_instance_id(), dealt, Stats.damage_color(unit.get_attack_damage_type()))   # one number with her beam
