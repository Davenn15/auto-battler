class_name PhaseStatus
extends Status
## Phased: taken out of the fight for a while. The unit can't act and can't be targeted or
## hit, tinted see-through blue. Every Phase in the game goes through phase() here (VE5TIBULE,
## the Phase Button keepsake, MALLET, BATR.EE).
##
## A unit Phased while none of its teammates are still fighting (every other one is dead or
## Phased too) only stays Phased for LONE_SHARE of the time. That includes a Phase already
## running when the last fighting teammate drops, so a lone unit can't stall a fight by
## Phasing over and over.

## Share of a Phase a unit with no fighting teammates gets (0.25 = a quarter as long).
const LONE_SHARE := 0.25
const FADE := 0.45   # the unit's opacity while Phased

var time_left: float
var full_time: float   # the whole Phase, for working out the lone length
var _cut := false


## Phases `unit` for `time` seconds. With a `source` (an enemy doing it), it's crowd control:
## immune units ignore it, it can wrack, and units that resist crowd control shorten it.
## Returns the Phase, or null if it didn't take. Phasing a unit already Phased lengthens it.
static func phase(unit: BattleUnit, time: float, source: BattleUnit = null) -> PhaseStatus:
	if unit == null or not unit.alive or time <= 0.0:
		return null
	if source != null:
		if unit.is_cc_immune():
			unit.show_float_text("Immune", PhaseGambit.PHASE_COLOR)
			return null
		if is_instance_valid(source):
			time *= source.wrack_effect_multiplier(Stats.EffectKind.CONTROL, false, unit)
		time *= unit.crowd_control_multiplier()
	var existing := of(unit)
	if existing != null:
		existing.full_time = maxf(existing.full_time, time)
		existing.time_left = maxf(existing.time_left, time)
		existing._cut = false
		existing._check_alone(unit)
		return existing
	var status := PhaseStatus.new()
	status.time_left = time
	status.full_time = time
	unit.add_status(status)
	return status


## The unit's Phase, or null if it isn't Phased.
static func of(unit: BattleUnit) -> PhaseStatus:
	if unit == null:
		return null
	for status in unit.statuses:
		if status is PhaseStatus:
			return status
	return null


static func is_phased(unit: BattleUnit) -> bool:
	return unit != null and unit.alive and of(unit) != null


## True if none of `unit`'s teammates are still fighting: each is dead, out of combat, or
## Phased.
static func is_alone(unit: BattleUnit) -> bool:
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other != null and other != unit and other.team == unit.team and other.alive \
				and other.active and not is_phased(other):
			return false
	return true


func on_applied(unit: BattleUnit) -> void:
	unit.modulate.a = FADE
	if unit.sprite != null:
		unit.sprite.self_modulate = KeepsakeVfx.PHASE_TINT
	unit.show_float_text("Phased", PhaseGambit.PHASE_COLOR)
	_check_alone(unit)


func on_removed(unit: BattleUnit) -> void:
	unit.modulate.a = 1.0
	if unit.sprite != null:
		unit.sprite.self_modulate = Color.WHITE


## A Phase never stops the unit gaining Charge on its own (being held in place does).
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func blocks_targeting(_unit: BattleUnit) -> bool:
	return true


## Can't be hit while Phased: every hit is dodged.
func modify_dodge_chance(_unit: BattleUnit, _chance: float) -> float:
	return 1.0


func tick(unit: BattleUnit, delta: float) -> void:
	if not unit.active or not unit.alive:
		unit.remove_status(self)
		return
	_check_alone(unit)
	# Held like a stun: no moving, attacking or casting, and no winding up an attack.
	unit.lock_for(delta * 2.0)
	unit._stunned_time = maxf(unit._stunned_time, delta * 2.0)
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)


## No fighting teammates left: what's left of the Phase drops to the lone length.
func _check_alone(unit: BattleUnit) -> void:
	if _cut or not is_alone(unit):
		return
	_cut = true
	time_left = minf(time_left, full_time * LONE_SHARE)
