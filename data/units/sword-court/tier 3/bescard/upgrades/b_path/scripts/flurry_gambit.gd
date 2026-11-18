class_name FlurryGambit
extends Gambit
## Unleashes a quick flurry of attacks on the current target. They're real attacks: they
## use the caster's normal damage, can wrack, and trigger on-attack effects.

@export var strikes: int = 5
## Seconds between strikes.
@export var strike_interval: float = 0.15
## Each strike that wracks adds one more strike, up to this many extra. 0 = off.
@export var max_wrack_extra_strikes: int = 0
## B2: each strike gains the Hit Effect: Bleed for this share of the target's max health
## (0.06 = 6%; see Bleed). 0 = none.
@export_range(0.0, 0.5, 0.005) var bleed_percent: float = 0.0


## Only fires once the current target is in reach, so the flurry isn't wasted walking.
func can_use(caster: BattleUnit) -> bool:
	return _in_reach(caster, caster.target)


func execute(caster: BattleUnit) -> void:
	if not _alive(caster):
		return
	var target = caster.target   # untyped: it may be freed while we wait
	if not _in_reach(caster, target):
		return
	# The same effects ride along on every strike. The flurry reads the wrack count
	# back after each one to see whether it earned an extra strike.
	var wracks := WrackCountHitEffect.new()
	var effects: Array[HitEffect] = [wracks]
	if bleed_percent > 0.0:
		effects.append(Bleed.BleedHit.new(caster.get_instance_id(), 0.0, bleed_percent))
	var done := 0
	while done < _total_strikes(wracks):
		# Either unit may have died, or the battle ended, while we were waiting.
		if not _alive(caster) or not caster.active or not _alive(target):
			return
		caster.lock_for((_total_strikes(wracks) - done) * strike_interval)
		# Each strike shows as a brutal slash across the target instead of the usual swing.
		caster.hide_next_swing = KeepsakeVfx.enabled()
		caster.attack_now(target, 0.0, 0.0, null, effects)
		caster.hide_next_swing = false
		KeepsakeVfx.brutal_slash(target, done)
		done += 1
		await caster.get_tree().create_timer(strike_interval, true, true).timeout


## Strikes in this flurry so far: the base count plus one per landed wrack, up to the cap.
func _total_strikes(wracks: WrackCountHitEffect) -> int:
	return strikes + mini(wracks.count, max_wrack_extra_strikes)


## Untyped on purpose: the unit may have been freed by the time this is called.
func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive


func _in_reach(caster: BattleUnit, unit) -> bool:
	return _alive(unit) and caster.grid.get_distance(caster.cell, unit.cell) <= caster.attack_range
