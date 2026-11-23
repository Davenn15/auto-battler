class_name ShieldBeamGambit
extends Gambit
## BEAM.NG channels a beam at the ally with the lowest share of its health (not itself),
## shielding it continuously: Shield Per Second + Insight Scaling x Insight, more the farther
## away it is (its passive). The shield lingers a little after the beam ends. If the target
## dies before the beam ends, it moves on to the next lowest-health ally for the time left.
##   A: the beam ricochets from its target to that ally's lowest-health nearby ally.
##   A1: allies under the beam gain Immovability.
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
## A1: Immovability allies have while the beam feeds them (0 = none).
@export var immovability: float = 0.0


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
	var fan := Beam.FanLines.new()   # extra Beams (BEAM.NG's hero Ascension)
	var shields := {}   # ally instance id -> its BeamShieldStatus
	var given := 0.0
	var elapsed := 0.0
	var tick_left := 0.0
	var charging := 0.0   # a new ally: the Beam charges up first (Beam.retarget_time)
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
			charging = Beam.retarget_time(caster.get_attack_cooldown())
			tick_left = 0.0
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
		var extras: Array = []
		if beam_settings.extra_beams > 0:
			extras = Beam.extra_beam_targets(caster, first, beam_settings.extra_beams, _range(caster), chain + [caster], true)
		fan.show(caster, extras, BeamngPassive.LIGHT)
		if charging > 0.0:
			charging -= delta * beam_settings.charge_up_speed
			continue
		tick_left -= delta
		if tick_left > 0.0:
			continue
		# A tick: the shielding for one tick interval, all at once (the same per second).
		var interval := Beam.tick_interval(caster.get_attack_cooldown())
		tick_left += interval
		links.pulse()
		fan.pulse()
		var per_second := Stats.scaled(shield_per_second, insight_scaling, caster.get_stat(Stats.Stat.INSIGHT)) \
				* beam_settings.rate
		var fed: Array = chain + extras
		for index in fed.size():
			var ally = fed[index]
			if not _alive(ally):
				continue
			var shield: BeamShieldStatus = shields.get(ally.get_instance_id())
			if shield == null or not ally.statuses.has(shield):
				shield = BeamShieldStatus.new(0.0, shield_linger)
				ally.add_status(shield)
				shields[ally.get_instance_id()] = shield
			var amount := per_second * BeamngPassive.distance_multiplier(caster, ally) * interval
			if index >= chain.size():
				amount *= beam_settings.extra_beam_share
			elif index >= own:
				amount *= beam_settings.ricochet_share
			shield.feed(amount, shield_linger, immovability)
			given += amount
	links.clear()
	fan.clear()
	if is_instance_valid(caster) and caster.is_inside_tree():
		caster.get_tree().call_group("damage_tracker", "record_shielding", caster.get_instance_id(), given)


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive


## A shield the beam keeps topping up. With A1 the ally has Immovability while
## the beam is on it.
class BeamShieldStatus extends ShieldStatus:
	var _immovability := 0.0
	var _fed := 0.0   # seconds since the beam last fed it, counted down

	func feed(amount: float, linger: float, immovability: float) -> void:
		shield += amount
		time_left = linger
		_immovability = immovability
		_fed = 0.15

	func tick(unit: BattleUnit, delta: float) -> void:
		_fed -= delta
		super.tick(unit, delta)

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat == Stats.Stat.IMMOVABILITY and _fed > 0.0:
			return value + _immovability
		return value
