class_name GlaiveRotor
extends Node2D
## One of Glaive's energy rotors: a blade circling him for its duration, damaging each enemy
## it sweeps through (each enemy at most once per lap). It follows Glaive around and
## vanishes if he dies.
##
## While any rotor is out Glaive can't gain Charge, unless the rotor is "cycling" (his A
## upgrade), which also lets him have several out at once (see RotorStatus).

var caster: BattleUnit
var time_left: float
var radius: float            # pixels from his centre to the blade's middle
var blade_half: float        # half the blade's length, in pixels
var laps_per_second: float
var damage: float
var damage_type: int
var ward_pierce: float       # A2: wards ignored by its hits
var angle := 0.0
var _last_hit := {}          # enemy instance id -> time (seconds) of its last hit
var _time := 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		queue_free()
		return
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	_time += delta
	angle = wrapf(angle + TAU * laps_per_second * delta, 0.0, TAU)
	global_position = caster.global_position
	var lap := 1.0 / laps_per_second
	var blade := Vector2.from_angle(angle)
	for node in get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not enemy.alive or enemy.team == caster.team or not enemy.is_targetable():
			continue
		var id := enemy.get_instance_id()
		if _time - float(_last_hit.get(id, -INF)) < lap * 0.9:
			continue
		# Hit if the enemy is within reach of any point along the blade.
		var offset := enemy.global_position - caster.global_position
		var along := clampf(offset.dot(blade), radius - blade_half, radius + blade_half)
		if offset.distance_to(blade * along) <= HIT_WIDTH:
			_last_hit[id] = _time
			_hit(enemy)


func _hit(enemy: BattleUnit) -> void:
	var amount := damage
	var ignore := false
	if ward_pierce > 0.0:
		var ward := enemy.get_stat(Stats.ward_stat_for(damage_type))
		amount *= Stats.ward_multiplier(maxf(ward - ward_pierce, 0.0))
		ignore = true   # the wards were already counted, less the pierce
	var dealt := enemy.take_damage(amount, 0, damage_type, ignore, caster)
	caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_credit_id(), dealt)


func _process(_delta: float) -> void:
	queue_redraw()


## A glowing blade at the end of a faint arm, with a short fading trail behind it.
func _draw() -> void:
	var fade := clampf(time_left / 0.3, 0.0, 1.0)
	for i in 6:
		var a := angle - i * 0.12
		var dir := Vector2.from_angle(a)
		var alpha := (1.0 - i / 6.0) * 0.35 * fade
		draw_line(dir * (radius - blade_half), dir * (radius + blade_half), Color(ROTOR_COLOR, alpha), 6.0, true)
	var dir := Vector2.from_angle(angle)
	draw_line(Vector2.ZERO, dir * (radius - blade_half), Color(ROTOR_COLOR, 0.15 * fade), 1.5, true)
	draw_line(dir * (radius - blade_half), dir * (radius + blade_half), Color(ROTOR_COLOR, 0.95 * fade), 5.0, true)
	draw_line(dir * (radius - blade_half), dir * (radius + blade_half), Color(1, 1, 1, 0.85 * fade), 1.5, true)


const HIT_WIDTH := 16.0   # how close to the blade an enemy's centre must be to be hit
const ROTOR_COLOR := Color(0.2, 0.85, 0.8)   # Glaive's teal: his rotors, saw spin and text
