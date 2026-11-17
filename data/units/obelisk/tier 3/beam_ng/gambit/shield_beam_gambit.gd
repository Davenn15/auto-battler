class_name ShieldBeamGambit
extends Gambit
## BEAM.NG channels a beam at the ally with the lowest share of its health (not itself),
## shielding it continuously: Shield Per Second + Insight Scaling x Insight, more the farther
## away it is (its passive). The shield lingers a little after the beam ends. If the target
## dies before the beam ends, it moves on to the next lowest-health ally for the time left.
##   A: the beam ricochets from its target to that ally's lowest-health nearby ally.
##   A1: allies under the beam are immune to crowd control.
##   A2: one more ricochet.
## A Beam (see Beam): BEAM.NG's Beam settings add range to the first target, speed up the
## shielding, and add extra ricochets (at their reduced share) after its own.

## Seconds BEAM.NG channels the beam.
@export var duration: float = 4.0
@export var shield_per_second: float = 30.0
@export var insight_scaling: float = 0.25
## Seconds the shield stays once the beam stops feeding it.
@export var shield_linger: float = 3.0
## How far the first target can be, in hex cells.
@export var range_cells: int = 6
## A: how many times the beam ricochets on from its target.
@export var bounces: int = 0
## How close the next ally must be to ricochet to, in hex cells.
@export var bounce_range_cells: int = 2
## A1: 1 = allies under the beam are immune to crowd control.
@export var cc_immune: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	return BeamLinks.lowest_ally(caster, caster, _range(caster), []) != null


func _range(caster: BattleUnit) -> int:
	return range_cells + Beam.settings(caster, Beam.Kind.SHIELD).range_bonus


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var first := BeamLinks.lowest_ally(caster, caster, _range(caster), [])
	if first == null:
		return
	caster.show_float_text("Shield Beam", BeamngPassive.LIGHT)
	var links := BeamLinks.new(caster)
	var shields := {}   # ally instance id -> its BeamShieldStatus
	var given := 0.0
	var elapsed := 0.0
	while elapsed < duration:
		caster.lock_for(0.1)   # channelling: a frame at a time, so it ends cleanly
		await caster.get_tree().physics_frame
		if not _alive(caster) or not caster.is_inside_tree() or not caster.active \
				or caster._stunned_time > 0.0:   # a stun ends the Beam
			break
		if not _alive(first):
			first = BeamLinks.lowest_ally(caster, caster, _range(caster), [])   # moved on
			if first == null:
				break
		var delta := caster.get_physics_process_delta_time()
		elapsed += delta
		var beam_settings := Beam.settings(caster, Beam.Kind.SHIELD)
		var chain: Array = [first]
		for i in bounces:
			var next := BeamLinks.lowest_ally(caster, chain.back(), bounce_range_cells, chain)
			if next == null:
				break
			chain.append(next)
		var own := chain.size()   # links past this are the Beam settings' extra ricochets
		chain.append_array(Beam.ricochet_targets(caster, chain.back(), beam_settings.extra_ricochets,
				beam_settings.ricochet_range, chain + [caster], true))
		links.show(chain, BeamngPassive.LIGHT)
		var per_second := Stats.scaled(shield_per_second, insight_scaling, caster.get_stat(Stats.Stat.INSIGHT)) \
				* beam_settings.rate
		for index in chain.size():
			var ally = chain[index]
			var shield: BeamShieldStatus = shields.get(ally.get_instance_id())
			if shield == null or not ally.statuses.has(shield):
				shield = BeamShieldStatus.new(0.0, shield_linger)
				ally.add_status(shield)
				shields[ally.get_instance_id()] = shield
			var amount := per_second * BeamngPassive.distance_multiplier(caster, ally) * delta
			if index >= own:
				amount *= beam_settings.ricochet_share
			shield.feed(amount, shield_linger, cc_immune > 0.0)
			given += amount
	links.clear()
	if is_instance_valid(caster) and caster.is_inside_tree():
		caster.get_tree().call_group("damage_tracker", "record_shielding", caster.get_instance_id(), given)


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive


## A shield the beam keeps topping up. With A1 the ally can't be crowd controlled while
## the beam is on it.
class BeamShieldStatus extends ShieldStatus:
	var _cc_immune := false
	var _fed := 0.0   # seconds since the beam last fed it, counted down

	func feed(amount: float, linger: float, immune: bool) -> void:
		shield += amount
		time_left = linger
		_cc_immune = immune
		_fed = 0.15

	func tick(unit: BattleUnit, delta: float) -> void:
		_fed -= delta
		super.tick(unit, delta)

	func blocks_crowd_control(_unit: BattleUnit) -> bool:
		return _cc_immune and _fed > 0.0
