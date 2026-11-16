class_name CtrlDrones
extends RefCounted
## CTRL(R)'s drones, shared by its passive and its Gambit.
##   Siphon drone (SiphonDrone, below). Flies to an enemy, beams away
##     a share of its max health (for the rest of combat), flies back and heals CTRL(R) that much.
##   Bore drone (Swarming, A): every siphon launch also sends Bores Per Siphon of these. Each
##     flies to an enemy, deals a little damage, drills away some of all three of its wards
##     (for the rest of combat) and brings them back to CTRL(R).
##   A2: every drone that makes it back gives CTRL(R) a Shield.

const DRONE_SPEED := 240.0
const CHANNEL_TIME := 1.5
## CTRL(R)'s colours: an orange-red for every drone, beam and pulse.
const COLOR := Color(1.0, 0.38, 0.18)
const LIGHT := Color(1.0, 0.72, 0.5)


## Sends a siphon drone from `unit` to `victim`, draining `share` of its max health, and
## (with Swarming) the bore drones that go with it.
static func launch_siphon(unit: BattleUnit, victim: BattleUnit, share: float, range_cells: int) -> void:
	if not is_instance_valid(victim) or not victim.alive:
		return
	var drone := SiphonDrone.new()
	drone.home = unit
	drone.victim = victim
	drone.total = victim.max_health * share
	drone.channel_time = CHANNEL_TIME
	drone.speed = DRONE_SPEED
	drone.z_index = 14
	drone.returned.connect(func(_d): on_drone_returned(unit))
	unit.get_parent().add_child(drone)
	drone.global_position = unit.global_position + SiphonDrone.HOVER
	var swarm := swarm_of(unit)
	if swarm != null:
		for target in bore_targets(unit, range_cells, swarm.bores):
			_launch_bore(unit, target, swarm)


## The enemies (up to `count`) within `range_cells` with the most health, most first. With
## fewer enemies than drones, the extra drones double up on them (all on one if it's alone).
static func siphon_targets(unit: BattleUnit, range_cells: int, count: int) -> Array:
	return _pick(unit, range_cells, count, func(e: BattleUnit): return e.health)


## Bore drones go for the enemies with the most total wards: the most to drill away.
static func bore_targets(unit: BattleUnit, range_cells: int, count: int) -> Array:
	return _pick(unit, range_cells, count, func(e: BattleUnit):
		return e.get_stat(Stats.Stat.MIGHT_WARD) + e.get_stat(Stats.Stat.INSIGHT_WARD) + e.get_stat(Stats.Stat.CELERITY_WARD))


static func enemies_in_range(unit: BattleUnit, range_cells: int) -> Array:
	var result := []
	for node in unit.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy != null and enemy.alive and enemy.active and enemy.team != unit.team \
				and unit.grid.get_distance(unit.cell, enemy.cell) <= range_cells:
			result.append(enemy)
	return result


static func _pick(unit: BattleUnit, range_cells: int, count: int, score: Callable) -> Array:
	var enemies := enemies_in_range(unit, range_cells)
	if enemies.is_empty():
		return []
	# Highest score first; ties by instance id so the order never depends on the tree's.
	enemies.sort_custom(func(a, b):
		var sa: float = score.call(a)
		var sb: float = score.call(b)
		return sa > sb if sa != sb else a.get_instance_id() < b.get_instance_id())
	var picks := []
	for i in count:
		picks.append(enemies[i % enemies.size()])
	return picks


static func swarm_of(unit: BattleUnit) -> SwarmStatus:
	for status in unit.statuses:
		if status is SwarmStatus:
			return status
	return null


## A drone (siphon or bore) got back to CTRL(R): A2's Shield.
static func on_drone_returned(unit: BattleUnit) -> void:
	if not is_instance_valid(unit) or not unit.alive:
		return
	for status in unit.statuses:
		if status is DroneShieldStatus:
			unit.add_shield(status.shield, status.duration, unit.get_instance_id())


static func _launch_bore(unit: BattleUnit, target: BattleUnit, swarm: SwarmStatus) -> void:
	var bore := BoreDrone.new()
	bore.home = unit
	bore.victim = target
	bore.damage = swarm.bore_damage
	bore.steal = swarm.ward_steal
	bore.speed = DRONE_SPEED * 1.15
	bore.z_index = 14
	unit.get_parent().add_child(bore)
	bore.global_position = unit.global_position + Vector2(0, -22)


## Swarming (A): on CTRL(R), holding the bore drone numbers.
class SwarmStatus extends Status:
	var bores: int
	var bore_damage: float
	var ward_steal: float

	func _init(p_bores: int, p_damage: float, p_steal: float) -> void:
		bores = p_bores
		bore_damage = p_damage
		ward_steal = p_steal


## A2: on CTRL(R), the Shield each returning drone gives.
class DroneShieldStatus extends Status:
	var shield: float
	var duration: float

	func _init(p_shield: float, p_duration: float) -> void:
		shield = p_shield
		duration = p_duration


## Wards moved by a bore drone, for the rest of combat: negative on the enemy it drilled,
## positive on CTRL(R) once the drone brings them home. Each drill adds its own.
class DrilledWards extends Status:
	var amount: float

	func _init(p_amount: float) -> void:
		amount = p_amount

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat in [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]:
			return value + amount
		return value


## A bore drone: out to its enemy on a curve, one drilling hit, then home with the wards.
class BoreDrone extends Node2D:
	const COLOR := CtrlDrones.COLOR
	const DRILL_TIME := 0.35   # how long it sits on the enemy, drilling, before the hit lands

	var home    # untyped: either may be freed
	var victim
	var damage := 30.0
	var steal := 7.0
	var speed := 270.0
	var _carrying := 0.0   # wards it's bringing back
	var _back := false
	var _drill := 0.0
	var _arc: Arc
	var _time := 0.0   # spin, on screen only

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(home) or not home.alive:
			queue_free()   # CTRL(R) is gone: the wards with it
			return
		if not _back:
			if not _alive(victim):
				_go_back()
				return
			if _arc == null:
				_arc = Arc.new()
			if _drill <= 0.0:
				if _arc.fly(self, victim.global_position, speed, delta):
					_drill = DRILL_TIME
			else:
				global_position = victim.global_position
				_drill -= delta
				if _drill <= 0.0:
					_hit()
					_go_back()
			return
		if _arc.fly(self, home.global_position, speed, delta):
			if _carrying > 0.0:
				home.add_status(DrilledWards.new(_carrying))
				home.show_float_text("+%d Wards" % roundi(_carrying), COLOR)
			CtrlDrones.on_drone_returned(home)
			queue_free()

	func _hit() -> void:
		if not _alive(victim):
			return
		var dealt: float = victim.take_damage(damage, 0, home.get_attack_damage_type(), false, home, false)
		BattleUnit.gambit_damage_dealt(home, victim, dealt)   # Gambit damage (see BattleUnit)
		home.get_tree().call_group("damage_tracker", "record_damage", home.get_credit_id(), dealt)
		victim.add_running_damage("bore_%d" % get_instance_id(), dealt,
				Stats.damage_color(home.get_attack_damage_type()), 0)
		if victim.alive and steal > 0.0:
			victim.add_status(DrilledWards.new(-steal))
			victim.show_float_text("-%d Wards" % roundi(steal), COLOR)
			_carrying = steal

	func _go_back() -> void:
		_back = true
		_arc = Arc.new()

	func _alive(unit) -> bool:
		return is_instance_valid(unit) and unit.alive

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	## A small orange body with a spinning drill bit pointing the way it flies (+x; the arc
	## turns the node to face along its path).
	func _draw() -> void:
		var spin := _time * 30.0
		draw_circle(Vector2(-3, 0), 5.0, Color(0.16, 0.16, 0.18))
		draw_arc(Vector2(-3, 0), 5.0, 0.0, TAU, 16, COLOR, 1.5, true)
		var tip := Vector2(9, 0)
		draw_colored_polygon(PackedVector2Array([Vector2(1, -4), tip, Vector2(1, 4)]), Color(0.8, 0.8, 0.85))
		for i in 3:   # the drill's thread, sliding toward the tip
			var t := fposmod(spin * 0.1 + i / 3.0, 1.0)
			var x := lerpf(1.0, 8.0, t)
			var h := lerpf(4.0, 0.5, t)
			draw_line(Vector2(x, -h), Vector2(x + 1.0, h), COLOR, 1.0, true)
		if _drill > 0.0:   # sparks while it drills
			for i in 4:
				var a := spin + i * TAU / 4.0
				draw_line(tip, tip + Vector2.from_angle(a) * 6.0, Color(1.0, 0.85, 0.4, 0.9), 1.2, true)


## A siphon drone: flies out on a curve, hovers over its enemy shining an orange-red beam
## down for Channel Time while it drains Total of its max health (for the rest of combat),
## then flies home and heals CTRL(R) for all of it. If the enemy dies mid-drain it comes
## back with what it has; if CTRL(R) dies, the drained health is lost.
class SiphonDrone extends Node2D:
	enum Stage { OUT, DRAIN, BACK }
	const HOVER := Vector2(0, -30)   # how far above a unit's middle the drone hovers
	const TICK := 0.1
	## Arrived back home (after healing it). A2 shields on this.
	signal returned(drone: Node2D)

	var home   # untyped: either may be freed
	var victim
	var total := 0.0
	var channel_time := 1.5
	var speed := 240.0
	var drained := 0.0
	var _stage := Stage.OUT
	var _channel := 0.0
	var _tick := 0.0
	var _time := 0.0       # rotors and beam only (on screen)
	var _leg := -1         # which leg the curve was set up for (a Stage); -1 = none yet
	var _arc: Arc

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(home) or not home.alive:
			queue_free()   # CTRL(R) is gone: the drained health with it
			return
		match _stage:
			Stage.OUT:
				if not _alive(victim):
					_stage = Stage.BACK
				elif _fly_to(victim.global_position + HOVER, delta):
					_stage = Stage.DRAIN
			Stage.DRAIN:
				if not _alive(victim):
					_stage = Stage.BACK
					return
				global_position = victim.global_position + HOVER
				_channel += delta
				_tick -= delta
				if _tick <= 0.0:
					_tick += TICK
					_drain(minf(total * TICK / channel_time, total - drained))
				if _channel >= channel_time or drained >= total:
					_stage = Stage.BACK
			Stage.BACK:
				if _fly_to(home.global_position + HOVER, delta):
					if drained > 0.0:
						home.heal(drained, home.get_instance_id())
						if KeepsakeVfx.enabled():
							KeepsakeVfx.heal_flash(home)
					returned.emit(self)
					queue_free()

	## Takes `amount` off the victim's max health (and health, if it's above the new max).
	func _drain(amount: float) -> void:
		if amount <= 0.0:
			return
		var new_max: float = victim.max_health - amount
		victim.resize_health(new_max, minf(victim.health, new_max))
		drained += amount

	## Each leg (out to the victim, back home) gets its own curve. True once there.
	func _fly_to(goal: Vector2, delta: float) -> bool:
		if _leg != _stage:
			_leg = _stage
			_arc = Arc.new()
		return _arc.fly(self, goal, speed, delta)

	func _alive(unit) -> bool:
		return is_instance_valid(unit) and unit.alive

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if _stage == Stage.DRAIN:
			# A beam of light from the drone down over the enemy, with rings rising up it
			# as the health is pulled in.
			var down := (-HOVER).rotated(-rotation)   # straight down on screen, in the drone's frame
			var side := down.orthogonal().normalized()
			var spread := 14.0
			var cone := PackedVector2Array([side * 3.0, -side * 3.0, down - side * spread, down + side * spread])
			draw_colored_polygon(cone, Color(CtrlDrones.COLOR, 0.28 + 0.08 * sin(_time * 12.0)))
			for ring in 3:
				var t := fposmod(_time * 1.6 + ring / 3.0, 1.0)
				var at := down * (1.0 - t)
				var w := lerpf(3.0, spread, 1.0 - t)
				draw_line(at - side * w, at + side * w, Color(CtrlDrones.LIGHT, 0.7 * t), 2.0)
		# Body with two spinning rotors, facing +x.
		draw_rect(Rect2(-5, -3, 10, 6), Color(0.3, 0.18, 0.14))
		draw_rect(Rect2(-5, -3, 10, 6), CtrlDrones.COLOR, false, 1.0)
		for s in [-1, 1]:
			var hub := Vector2(0, s * 6)
			var blade := Vector2.from_angle(_time * 30.0) * 5.0
			draw_line(hub - blade, hub + blade, Color(CtrlDrones.LIGHT, 0.8), 1.5)
		draw_circle(Vector2(5, 0), 1.5, Color(1.0, 0.85, 0.4))
		if drained > 0.0 and _stage == Stage.BACK:
			draw_circle(Vector2(-7, 0), 2.0 + minf(drained / 60.0, 3.0), Color(CtrlDrones.LIGHT, 0.9))   # the stolen health


## A curved flight from where a drone starts to a (possibly moving) goal: a smooth arc that
## bows out to one side, so it always lands on the goal, near or far. Worked out from
## positions only, so it's the same on every machine. Start a new Arc for each trip.
class Arc extends RefCounted:
	## How far the arc bows out, as a share of the trip's length.
	const BOW := 0.45
	var _start := Vector2.ZERO
	var _side := 1.0
	var _t := 0.0        # 0 at the start, 1 on arrival
	var _begun := false

	## Moves `drone` along the arc toward `goal`, `speed` pixels per second. True once it
	## has arrived (and it's then exactly on the goal).
	func fly(drone: Node2D, goal: Vector2, speed: float, delta: float) -> bool:
		if not _begun:
			_begun = true
			_start = drone.global_position
			_side = 1.0 if goal.x >= _start.x else -1.0
		var length := maxf(_start.distance_to(goal) * (1.0 + BOW * 0.6), 1.0)   # about the arc's length
		_t = minf(_t + speed * delta / length, 1.0)
		var before := drone.global_position
		drone.global_position = point(goal, _t)
		var moved := drone.global_position - before
		if moved.length_squared() > 0.0001:
			drone.rotation = moved.angle()
		return _t >= 1.0

	## Where along the arc a share `t` of the way is.
	func point(goal: Vector2, t: float) -> Vector2:
		var mid := (_start + goal) * 0.5
		var off := (goal - _start).orthogonal() * BOW * _side
		var control := mid - off
		return _start.lerp(control, t).lerp(control.lerp(goal, t), t)
