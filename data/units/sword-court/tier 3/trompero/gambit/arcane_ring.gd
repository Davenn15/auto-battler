class_name ArcaneRing
extends Node2D
## A ring on the ground that deals damage to enemies inside it every tick, then explodes
## for a final burst that stuns everyone still inside. Everything it needs is copied in
## when it's cast, so it keeps going even if the caster dies.

const TICK_INTERVAL := 0.5   # seconds between damage ticks
const COLOR := Color(0.708, 0.094, 0.297, 1.0)   # violet
## The outline's ripple: how many waves go round, how tall they are in pixels, and how
## fast they turn (radians per second).
const WAVES := 9
const WAVE_HEIGHT := 2.5
const WAVE_SPEED := 2.0
const OUTLINE_POINTS := 96

var _spin := 0.0

var caster_id: int
var team: int
var grid: BattleGrid
var center: Vector2i
var radius_cells: int
var tick_damage: float
var burst_damage: float
var stun_time: float
var damage_type: int
var wrack_chance: float = 0.0          # rolled once per tick and once for the burst
var wrack_multiplier: float = 1.0
var insight_drain: float = 0.0         # Insight enemies lose while inside. 0 = none
var charge_per_burst_hit: float = 0.0  # charge the caster gains per enemy the burst damages
var charge_lock: ChargeLock = null     # on the caster until the burst; null = none
var _time_left: float
var _duration: float = 1.0   # for the timer ring
var _tick_timer: float = TICK_INTERVAL


func setup(p_caster: BattleUnit, p_center: Vector2i, p_radius_cells: int, p_duration: float,
		p_tick_damage: float, p_burst_damage: float, p_stun_time: float, p_type: int) -> void:
	caster_id = p_caster.get_instance_id()
	team = p_caster.team
	grid = p_caster.grid
	center = p_center
	radius_cells = p_radius_cells
	_time_left = p_duration
	_duration = maxf(p_duration, 0.01)
	tick_damage = p_tick_damage
	burst_damage = p_burst_damage
	stun_time = p_stun_time
	damage_type = p_type
	z_index = -1   # draw under the units


func _physics_process(delta: float) -> void:
	_time_left -= delta
	_tick_timer -= delta
	var inside := _enemies_inside()
	if insight_drain > 0.0:
		for enemy in inside:
			_drain(enemy)
	if _tick_timer <= 0.0:
		_tick_timer += TICK_INTERVAL
		var wrack_level := Stats.roll_wrack(wrack_chance)   # one roll per tick, for everyone it hits
		for enemy in inside:
			_damage(enemy, tick_damage, wrack_level)
	if _time_left <= 0.0:
		_explode()


func _explode() -> void:
	set_physics_process(false)   # stop ticking; the fade below finishes the ring off
	var wrack_level := Stats.roll_wrack(wrack_chance)
	var hits := 0
	for enemy in _enemies_inside():
		if _damage(enemy, burst_damage, wrack_level) > 0.0:
			hits += 1   # a dodged burst doesn't count
		if enemy.alive:
			enemy.stun(stun_time, instance_from_id(caster_id) as BattleUnit)
	var caster := instance_from_id(caster_id) as BattleUnit
	_release_charge_lock()   # before the burst's charge, so he gets it
	if caster != null and charge_per_burst_hit > 0.0 and hits > 0:
		caster.gain_charge(charge_per_burst_hit * hits)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


## Lets the caster gain Charge again.
func _release_charge_lock() -> void:
	var caster := instance_from_id(caster_id) as BattleUnit
	if charge_lock != null and caster != null and caster.statuses.has(charge_lock):
		caster.remove_status(charge_lock)
	charge_lock = null


## A ring removed early (the battle ending) doesn't leave him locked.
func _exit_tree() -> void:
	_release_charge_lock()


## On the caster while his ring is out: he can't gain Charge until it explodes.
class ChargeLock extends Status:
	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return true


func _damage(enemy: BattleUnit, amount: float, wrack_level: int) -> float:
	amount *= pow(wrack_multiplier, wrack_level)
	var dealt := enemy.take_damage(amount, wrack_level, damage_type)
	get_tree().call_group("damage_tracker", "record_damage", caster_id, dealt)
	return dealt


## Keeps this ring's Insight drain on `enemy` while it stands inside.
func _drain(enemy: BattleUnit) -> void:
	for status in enemy.statuses:
		if status is InsightDrainStatus and status.source_id == get_instance_id():
			status.refresh()
			return
	enemy.add_status(InsightDrainStatus.new(get_instance_id(), insight_drain))


## Living enemies standing within the ring. Skips units that are out of combat, so a ring
## still on the ground when the battle ends doesn't keep hurting anyone.
func _enemies_inside() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or not unit.alive or not unit.active or unit.team == team:
			continue
		if grid.get_distance(center, unit.cell) <= radius_cells:
			result.append(unit)
	return result


## Only for the look: turns the wavy outline. Gameplay runs in _physics_process.
func _process(delta: float) -> void:
	_spin += delta
	queue_redraw()


func _draw() -> void:
	var r := (radius_cells + 0.5) * grid.cell_spacing()   # reaches the outer edge of the last cell
	draw_circle(Vector2.ZERO, r, Color(COLOR, 0.15))
	# A slightly wavy outline that slowly turns.
	var points := PackedVector2Array()
	for i in OUTLINE_POINTS + 1:
		var angle := TAU * i / OUTLINE_POINTS
		var wave := WAVE_HEIGHT * sin(angle * WAVES - _spin * WAVE_SPEED)
		points.append(Vector2.from_angle(angle) * (r + wave))
	draw_polyline(points, COLOR, 2.0, true)
	# The fuse: a fainter ring that grows from the middle and reaches the edge as it explodes.
	var fuse := clampf(1.0 - _time_left / _duration, 0.0, 1.0)
	if fuse > 0.0 and fuse < 1.0:
		draw_arc(Vector2.ZERO, r * fuse, 0.0, TAU, 64, Color(COLOR.lightened(0.3), 0.4), 1.5, true)
