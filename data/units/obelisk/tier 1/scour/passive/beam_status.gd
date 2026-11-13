class_name BeamStatus
extends Status
## Scour's attack: a continuous beam instead of shots. It fires in short ticks, each dealing
## its slice of a normal attack (so over one attack interval it deals one attack's damage)
## and rolling Wrack on its own. When the beam swaps targets it charges up for a moment
## before it deals damage.
##
## Things that happen once per attack (Charge from attacking and being hit, "on attack"
## and "on hit" effects, item hit effects, the damage number) are gathered and happen once
## per attack's worth of beam, so items don't trigger ten times as often. Vampirism heals
## from each tick's damage, which comes to the same total.
##
## Scour's upgrades tune it through the ramp settings (see BeamBoostPassive).

const TICK := 0.1   # seconds between beam ticks

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


func _init(p_retarget_delay: float) -> void:
	retarget_delay = p_retarget_delay


func on_removed(_unit: BattleUnit) -> void:
	if is_instance_valid(_visual):
		_visual.queue_free()


func blocks_attacks(_unit: BattleUnit) -> bool:
	return true   # the beam is its only attack


func tick(unit: BattleUnit, delta: float) -> void:
	# The beam is the only attack: keep the normal attack from ever firing.
	unit._attack_timer = maxf(unit._attack_timer, 1.0)
	var enemy = unit.target
	if not _can_fire(unit, enemy):
		_show(unit, null, false)
		return
	if enemy != _target:
		_flush(unit)
		_target = enemy
		_charging = retarget_delay
		_firing_time = 0.0
		_tick_left = 0.0
	if _charging > 0.0:
		_charging -= delta
		_show(unit, enemy, false)
		return
	_show(unit, enemy, true)
	_firing_time += delta
	_tick_left -= delta
	while _tick_left <= 0.0 and _alive(enemy):
		_tick_left += TICK
		_fire_tick(unit, enemy, TICK / unit.get_attack_cooldown())
	if not _alive(enemy):
		_flush(unit)


func _can_fire(unit: BattleUnit, enemy) -> bool:
	return unit.active and unit.alive and _alive(enemy) and unit._stunned_time <= 0.0 \
			and not unit._is_channeling() and not unit._moving and unit._is_valid_target(enemy) \
			and unit.grid.get_distance(unit.cell, enemy.cell) <= unit.attack_range


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
	_dealt += dealt
	_best_wrack = maxi(_best_wrack, wrack_level)
	_progress += share
	if _progress >= 1.0 / maxf(proc_rate(unit), 0.01) or not enemy.alive:
		_flush(unit)


## Hooks for beams built on this one (BEAM.NG). Scour leaves them as they are.
## Multiplies each tick's damage.
func damage_multiplier(_unit: BattleUnit, _enemy: BattleUnit) -> float:
	return 1.0

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
	for status in unit.statuses.duplicate():
		var effect: HitEffect = status.get_hit_effect(unit)
		if effect != null:
			effects.append(effect)
		status.on_attack(unit)
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

	func _process(delta: float) -> void:
		if not is_instance_valid(owner_unit) or not owner_unit.alive:
			queue_free()
			return
		time += delta
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(target) or not is_instance_valid(owner_unit):
			return
		# Converted into this node's own space: the scene it sits in may be moved or turned
		# (the random battle scene's root is offset), so world points can't be drawn directly.
		var from := to_local(owner_unit.global_position + Vector2(0, -10).rotated(owner_unit.global_rotation))
		var to := to_local(target.global_position)
		if firing:
			var pulse := 1.0 + 0.25 * sin(time * 30.0)
			draw_line(from, to, Color(color, 0.3), 9.0 * pulse, true)
			draw_line(from, to, Color(color, 0.95), 3.5, true)
			draw_line(from, to, Color(1, 1, 1, 0.9), 1.2, true)
			draw_circle(to, 5.0 * pulse, Color(color, 0.7))
		else:
			var flicker := 0.25 + 0.25 * absf(sin(time * 25.0))
			draw_line(from, to, Color(color, flicker), 1.5, true)
