class_name Revive
extends RefCounted
## The Revive keyword (an Obelisk mechanic): a unit that comes back after dying, with a share
## of its health, and then decays: it takes Pure Damage every second, DECAY_START of its max
## health at first, DECAY_RAMP more each second, until it dies again. Recycloid B (a copy of
## a fallen ally), Gateway B (the fallen ally itself), Backup Protocol (in place) and the
## Synthecyst all Revive this way.
##
## A revived unit is also a Construct (see is_construct).
##
## To revive a unit made fresh (a copy): Revive.mark(unit) before it joins the fight
## (BattleManager.add_summon), then Revive.start(unit, health) after.

const DECAY_START := 0.02   # share of max health per second at first...
const DECAY_RAMP := 0.02    # ...growing by this much more every second
const META := "revived"
const COLOR := Color(0.75, 0.9, 0.6)


## Marks `unit` as revived. Call before it joins the fight, so its Ascensions see it.
static func mark(unit: BattleUnit) -> void:
	unit.set_meta(META, true)


static func is_revived(unit: BattleUnit) -> bool:
	return unit != null and unit.has_meta(META)


## The Construct keyword: a unit that didn't start combat on its army's board (a summon, a
## copy, a duplicate) or that Revived.
static func is_construct(unit: BattleUnit) -> bool:
	return unit != null and (unit.is_summon or is_revived(unit))


## Starts the revival: sets its health and begins the decay, and tells its statuses.
static func start(unit: BattleUnit, health: float) -> void:
	mark(unit)
	unit.set_health(clampf(health, 1.0, unit.max_health))
	if not unit.statuses.any(func(s): return s is DecayStatus):
		unit.add_status(DecayStatus.new())
	for status in unit.statuses.duplicate():
		status.on_revived(unit)


## The decay: ramping Pure Damage every second, for good. A sickly green tint shows it.
class DecayStatus extends Status:
	var _time := 0.0

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_applied(unit: BattleUnit) -> void:
		unit.modulate = Color(0.75, 1.0, 0.75)

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active:
			return
		_time += delta
		var burn := unit.max_health * (Revive.DECAY_START + Revive.DECAY_RAMP * _time) * delta
		unit.add_running_damage("self_burn", unit.take_warded_damage(burn, false, Stats.DamageType.PURE), Revive.COLOR)
