class_name BeamStatus
extends Status
## Scour's attack: a continuous beam instead of shots. It ticks in the Beam keyword's
## rhythm (Beam.TICKS_PER_ATTACK ticks per attack interval, each a slice of a normal attack,
## so over one attack interval it deals one attack's damage), each tick rolling Wrack on
## its own. When the beam swaps targets it charges up (Beam.retarget_time) before it deals
## damage.
##
## Things that happen once per attack (Charge from attacking and being hit, "on attack"
## and "on hit" effects, item hit effects, the damage number) are gathered and happen once
## per attack's worth of beam, so items don't trigger ten times as often. Vampirism heals
## from each tick's damage, which comes to the same total.
##
## Scour's upgrades tune it through the ramp settings (see BeamBoostPassive).
##
## A Beam (see Beam): each frame it reads the unit's Beam settings for more range, faster
## delivery, faster ramps and charge-up, and extra ricochets.

## Unused: every Beam now retargets by the keyword's rule (Beam.retarget_time). Kept so
## older resources that still set it load.
var retarget_delay: float
## Cutting (A): attack damage grows with sustained fire on one target, resetting on a swap.
var damage_ramp_per_second := 0.0   # 0.25 = +25% damage per second of firing
var max_damage_ramp := 0.0          # cap on that bonus (1.0 = up to +100%)
## A1: Wrack chance grows the same way.
var wrack_ramp_per_second := 0.0    # 0.1 = +10% Wrack chance per second
var max_wrack_ramp := 0.0

var _target = null          # untyped: may be freed
var _charging := 0.0        # seconds left before the beam deals damage
var _firing_time := 0.0     # seconds of sustained fire on the current target
var _tick_left := 0.0
var _progress := 0.0        # share of an attack delivered since the last full one
var _dealt := 0.0           # damage dealt since the last full attack
var _best_wrack := 0        # highest Wrack level since the last full attack
var _visual: BeamLine = null
## Seconds since the last tick (for visuals that pulse with it, like Mother-Chip's Chips).
var pulse_age := 99.0
var _range_given := 0   # Beam range bonus currently added to the unit's attack range
var _ricochet_lines := Beam.RicochetLines.new()
var _fan_lines := Beam.FanLines.new()   # extra Beams (Beam's hero Ascension)


func _init(p_retarget_delay: float) -> void:
	retarget_delay = p_retarget_delay


func on_removed(unit: BattleUnit) -> void:
	if is_instance_valid(_visual):
		_visual.queue_free()
	_ricochet_lines.clear()
	if is_instance_valid(unit):
		unit.attack_range -= _range_given
	_range_given = 0
	_fan_lines.clear()


func blocks_attacks(_unit: BattleUnit) -> bool:
	return true   # the beam is its only attack


func tick(unit: BattleUnit, delta: float) -> void:
	# The beam is the only attack: keep the normal attack from ever firing.
	unit._attack_timer = maxf(unit._attack_timer, 1.0)
	pulse_age += delta
	var beam := Beam.settings(unit, Beam.Kind.ATTACK)
	if beam.range_bonus != _range_given:   # the Beam's reach is the unit's attack range
		unit.attack_range += beam.range_bonus - _range_given
		_range_given = beam.range_bonus
	var enemy = unit.target
	if not _can_fire(unit, enemy):
		_show(unit, null, false)
		_ricochet_lines.clear()
		_fan_lines.clear()
		return
	if enemy != _target:
		_flush(unit)
		_target = enemy
		_charging = Beam.retarget_time(unit.get_attack_cooldown())
		_firing_time = 0.0
		_tick_left = 0.0
	if _charging > 0.0:
		_charging -= delta * beam.charge_up_speed
		_show(unit, enemy, false)
		_ricochet_lines.clear()
		_fan_lines.clear()
		return
	_show(unit, enemy, true)
	_firing_time += delta * beam.ramp_speed
	_tick_left -= delta
	var ricochets: Array = []
	if beam.extra_ricochets > 0:
		ricochets = Beam.ricochet_targets(unit, enemy, beam.extra_ricochets, beam.ricochet_range, [enemy])
	_ricochet_lines.show(enemy, ricochets, beam_color(unit))
	var extras: Array = []
	if beam.extra_beams > 0:
		extras = Beam.extra_beam_targets(unit, enemy, beam.extra_beams, unit.attack_range, [enemy] + ricochets)
	_fan_lines.show(unit, extras, beam_color(unit))
	while _tick_left <= 0.0 and _alive(enemy):
		_tick_left += Beam.tick_interval(unit.get_attack_cooldown())
		var share := Beam.tick_share(beam)
		_fire_tick(unit, enemy, share)
		Beam.notify_tick(unit, enemy)
		if not ricochets.is_empty():
			_dealt += Beam.hit_ricochets(unit, ricochets, Beam.tick_damage(unit, share) * beam.ricochet_share)
		if not extras.is_empty():
			_dealt += Beam.hit_ricochets(unit, extras, Beam.tick_damage(unit, share) * beam.extra_beam_share)
			_fan_lines.pulse()
		pulse_age = 0.0
		if is_instance_valid(_visual):
			_visual.pulse()
		_ricochet_lines.pulse()
	if not _alive(enemy):
		_flush(unit)


## The beam is the unit's attack, so whatever would stop an attack stops it (see
## BattleUnit.can_attack_now): stuns, casting, moving, an invalid or out-of-range target...
func _can_fire(unit: BattleUnit, enemy) -> bool:
	return _alive(enemy) and unit.can_attack_now(enemy, self)


func _fire_tick(unit: BattleUnit, enemy: BattleUnit, share: float) -> void:
	var chance := unit.get_stat(Stats.Stat.WRACK_CHANCE)
	for status in unit.statuses:
		chance = status.modify_wrack_chance(unit, enemy, chance)
	chance += minf(wrack_ramp_per_second * _firing_time, max_wrack_ramp)
	var wrack_level := Stats.roll_wrack(chance)
	var base := Stats.attack_damage(unit.get_stat(Stats.Stat.MIGHT))
	for status in unit.statuses.duplicate():
		base = status.modify_outgoing_damage(unit, base)
	base *= 1.0 + minf(damage_ramp_per_second * _firing_time, max_damage_ramp)
	base *= damage_multiplier(unit, enemy)
	var hit := base * share * Stats.wrack_multiplier(wrack_level, unit.get_wrack_damage_against(enemy))
	var dealt := enemy.take_damage(hit, wrack_level, unit.get_attack_damage_type(), unit.ignores_wards(), unit, false)
	unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), dealt)
	enemy.add_running_damage("beam_%d" % unit.get_instance_id(), dealt, Stats.damage_color(unit.get_attack_damage_type(), wrack_level), wrack_level)
	if from_gambit:   # a Gambit's beam (Focus Beam): Gambit damage
		BattleUnit.gambit_damage_dealt(unit, enemy, dealt)
	_dealt += dealt
	_best_wrack = maxi(_best_wrack, wrack_level)
	_progress += share
	if _progress >= 1.0 / maxf(proc_rate(unit), 0.01) or not enemy.alive:
		_flush(unit)


## Hooks for beams built on this one (Beam). Scour leaves them as they are.
## Multiplies each tick's damage.
func damage_multiplier(_unit: BattleUnit, _enemy: BattleUnit) -> float:
	return 1.0

func is_attack_beam() -> bool:
	return true

## How often once-per-attack effects trigger: 1 = once per attack's worth of beam,
## 1.3 = 30% more often.
func proc_rate(_unit: BattleUnit) -> float:
	return 1.0

## The beam's colour on screen.
func beam_color(unit: BattleUnit) -> Color:
	return BattleUnit.team_color(unit.team).lightened(0.25)


## One attack's worth of beam has landed (or the beam stopped): everything that happens
## once per attack, using the damage gathered since the last time.
func _flush(unit: BattleUnit) -> void:
	if _progress <= 0.0:
		return
	var enemy = _target
	var dealt := _dealt
	var wrack := _best_wrack
	_progress = 0.0
	_dealt = 0.0
	_best_wrack = 0
	var effects: Array[HitEffect] = []
	Beam.flushing = true   # on_attack here is the Beam's attack's worth, not a tick
	for status in unit.statuses.duplicate():
		var effect: HitEffect = status.get_hit_effect(unit)
		if effect != null:
			effects.append(effect)
		status.on_attack(unit)
	Beam.flushing = false
	effects = unit.repeat_hit_effects(effects)
	if not is_instance_valid(enemy):
		return
	if dealt > 0.0:
		unit.gain_charge_from_attack(dealt, enemy)
		enemy.gain_charge_from_hit(dealt)
	enemy.notify_attacked(unit, dealt)
	unit.notify_attack_hit(enemy, dealt)
	BattleUnit.run_hit_effects(effects, enemy, dealt, wrack)


func _alive(unit) -> bool:
	return is_instance_valid(unit) and unit.alive


## The beam on screen: thin and flickering while it charges, solid while it fires.
func _show(unit: BattleUnit, enemy, firing: bool) -> void:
	if not KeepsakeVfx.enabled():
		return
	if enemy == null:
		if is_instance_valid(_visual):
			_visual.visible = false
		return
	if not is_instance_valid(_visual):
		_visual = BeamLine.new()
		_visual.owner_unit = unit
		_visual.z_index = 9
		unit.get_tree().current_scene.add_child(_visual)
	_visual.visible = true
	_visual.target = enemy
	_visual.firing = firing
	_visual.color = beam_color(unit)


## Draws the beam between its unit and target, every frame.
class BeamLine extends Node2D:
	var owner_unit: BattleUnit
	var target = null
	var firing := false
	var color := Color.WHITE
	var time := 0.0
	## Where on the owner's sprite the beam starts, in the sprite's own pixels from its
	## centre (e.g. Column's portals). Null = the default spot just above the unit.
	var sprite_point = null
	var _pulses: Array = []   # seconds since each recent tick's pulse set off

	## A tick: a bright bead travels down the beam and flares where it lands.
	func pulse() -> void:
		_pulses.append(0.0)

	func _process(delta: float) -> void:
		if not is_instance_valid(owner_unit) or not owner_unit.alive:
			queue_free()
			return
		time += delta
		for i in _pulses.size():
			_pulses[i] += delta
		_pulses = _pulses.filter(func(age): return age < Beam.PULSE_TRAVEL + Beam.PULSE_FLARE)
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(target) or not is_instance_valid(owner_unit):
			return
		# Converted into this node's own space: the scene it sits in may be moved or turned
		# (the random battle scene's root is offset), so world points can't be drawn directly.
		var from_world := owner_unit.global_position + Vector2(0, -10).rotated(owner_unit.global_rotation)
		if sprite_point != null and is_instance_valid(owner_unit.sprite):
			from_world = owner_unit.sprite.to_global(sprite_point)
		var from := to_local(from_world)
		# The line stops at the target's sprite as drawn, not its centre.
		var to := to_local(SpriteEdge.edge_point(target, from_world))
		if firing:
			# Steady and a little dim between ticks; each tick's pulse runs down it.
			draw_line(from, to, Color(color, 0.18), 7.0, true)
			draw_line(from, to, Color(color, 0.65), 2.5, true)
			draw_line(from, to, Color(1, 1, 1, 0.45), 1.0, true)
			for age in _pulses:
				if age < Beam.PULSE_TRAVEL:
					var t: float = age / Beam.PULSE_TRAVEL
					var at := from.lerp(to, t)
					var tail := from.lerp(to, maxf(t - 0.18, 0.0))
					draw_line(tail, at, Color(color, 0.9), 5.0, true)
					draw_circle(at, 4.5, Color(1, 1, 1, 0.95))
					draw_circle(at, 7.0, Color(color, 0.45))
				else:
					var f: float = (age - Beam.PULSE_TRAVEL) / Beam.PULSE_FLARE
					draw_circle(to, 4.0 + 8.0 * f, Color(color, 0.8 * (1.0 - f)))
					draw_circle(to, 3.0, Color(1, 1, 1, 0.9 * (1.0 - f)))
		else:
			var flicker := 0.25 + 0.25 * absf(sin(time * 25.0))
			draw_line(from, to, Color(color, flicker), 1.5, true)
