class_name SegFx
extends RefCounted
## Fault's look: white.

const COLOR := Color(1.0, 1.0, 1.0)
const LIGHT := Color(0.85, 0.92, 1.0)


## A white glitch burst where it blinks out or in.
static func blink(at: Vector2, parent: Node) -> void:
	if not KeepsakeVfx.enabled() or parent == null:
		return
	KeepsakeVfx.missile_blast(parent, at, 26.0, COLOR)


## The Gambit's teleport: a digital trail from where it was to where it lands, a line of
## flickering white pixel blocks that scatters and fades.
static func teleport_trail(parent: Node, from: Vector2, to: Vector2) -> void:
	if not KeepsakeVfx.enabled() or parent == null or from.distance_to(to) < 2.0:
		return
	var trail := DigitalTrail.new()
	trail.start = from
	trail.end = to
	trail.z_index = 12
	parent.add_child(trail)
	trail.global_position = Vector2.ZERO


## The cannon's blast: a thick white line from `from` to `to` that fades.
static func cannon_line(parent: Node, from: Vector2, to: Vector2, width: float) -> void:
	if not KeepsakeVfx.enabled() or parent == null:
		return
	for pass_width in [width, width * 0.4]:
		var line := Line2D.new()
		line.points = PackedVector2Array([from, to])
		line.width = pass_width
		line.default_color = Color(LIGHT, 0.45) if pass_width == width else COLOR
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.z_index = 13
		parent.add_child(line)
		line.global_position = Vector2.ZERO
		var tween := line.create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.45)
		tween.tween_callback(line.queue_free)


## A white blast `radius` pixels across at `at`.
static func burst(parent: Node, at: Vector2, radius: float) -> void:
	if not KeepsakeVfx.enabled() or parent == null:
		return
	KeepsakeVfx.missile_blast(parent, at, radius, COLOR)


## See teleport_trail. Pixel blocks are laid along the path every few pixels, nudged off
## it a little, and each flickers on and off as the whole trail fades, the far end
## (where it left) first. Purely visual, with its own random numbers.
class DigitalTrail extends Node2D:
	const TIME := 0.7
	const SPACING := 7.0       # pixels between blocks along the path
	const BLOCK := 3.0         # half the size of a block
	const SCATTER := 5.0       # how far a block can sit off the path
	var start := Vector2.ZERO
	var end := Vector2.ZERO
	var _age := 0.0
	var _blocks: Array = []    # [position, size, flicker phase, fade delay]
	var _rng := RandomNumberGenerator.new()   # its own: never disturbs anyone else's random numbers

	func _ready() -> void:
		var length := start.distance_to(end)
		var side := (end - start).orthogonal().normalized()
		var count := maxi(int(length / SPACING), 2)
		for i in count + 1:
			var t := float(i) / count
			var at := start.lerp(end, t) + side * _rng.randf_range(-SCATTER, SCATTER)
			var size := BLOCK * _rng.randf_range(0.6, 1.3)
			_blocks.append([at, size, _rng.randf() * TAU, (1.0 - t) * 0.35])
		# A few stray "glitch" bars across the path.
		for i in 4:
			var t := _rng.randf()
			_blocks.append([start.lerp(end, t), -_rng.randf_range(6.0, 12.0), _rng.randf() * TAU, (1.0 - t) * 0.35])

	func _process(delta: float) -> void:
		_age += delta
		if _age >= TIME:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		for block in _blocks:
			var life := clampf((TIME - _age - float(block[3]) * 0.5) / TIME, 0.0, 1.0)
			if life <= 0.0:
				continue
			if sin(_age * 40.0 + float(block[2])) < -0.4:
				continue   # flickered off this frame
			var at: Vector2 = block[0]
			var size: float = block[1]
			var color := Color(SegFx.COLOR if size > 0.0 else SegFx.LIGHT, life)
			if size > 0.0:
				draw_rect(Rect2(at - Vector2(size, size), Vector2(size, size) * 2.0), color)
			else:
				draw_rect(Rect2(at - Vector2(-size, 1.0), Vector2(-size * 2.0, 2.0)), Color(color, life * 0.7))


## One ion bolt of the salvo. It's a Projectile, so everything that cares about projectiles
## treats it as one: an enemy area that slows shots (Bubbler's bubble) slows it, and an
## enemy that sends projectiles back (Glaive's spin, a parry, Balmede's plant, Wesper) can.
## On landing it calls `on_hit(target)` (the Gambit's hit: damage, Silence, A2's debuff).
## Sent back, it belongs to the reflector and just deals its damage: no Silence, no debuff,
## and it isn't Fault's Gambit damage any more. Gameplay, so it runs in sims too; only
## its drawing is skipped there.
class IonBolt extends Projectile:
	const BOLT_SPEED := 350.0
	const OVAL := Vector2(8.0, 4.5)   # half-width and half-height of the oval
	const SPIN := 12.0                # radians a second it turns
	var on_hit: Callable
	var _reflected := false
	## Fault's hero Ascension (SegBounceEffect): after hitting its target the bolt flies
	## on to the board's edge, bounces once, and hits the first enemy on its way back.
	var bounces := 0
	var _grid: BattleGrid
	var _free_flight := false   # past its target, heading for the edge or back
	var _free_dir := Vector2.ZERO
	var _bounced := false
	var _trail: Array[Vector2] = []
	var _spin := 0.0

	## Fills it in before it's added to the scene. `amount` is what it deals if sent back
	## (the Gambit's own hit works its damage out when it lands).
	func setup_ion(caster: BattleUnit, p_target: BattleUnit, amount: float) -> void:
		shooter_id = caster.get_instance_id()
		credit_id = caster.get_credit_id()
		team = caster.team
		target = p_target
		damage = amount
		damage_type = Stats.DamageType.INSIGHT
		is_attack = false
		grants_charge = false
		speed = BOLT_SPEED
		polygon = PackedVector2Array()   # drawn as an oval below, not the plain comet
		z_index = 12
		_grid = caster.grid
		bounces = 1 if SegBounceEffect.has_on(caster) else 0

	func _process(delta: float) -> void:
		_spin = wrapf(_spin + SPIN * delta, 0.0, TAU)   # only the drawing turns

	func _physics_process(delta: float) -> void:
		var before := global_position
		if _free_flight:
			_fly_free(delta)
		else:
			super(delta)   # flies like any Projectile (homing, slowed by bubbles, edge hits)
		if is_queued_for_deletion() or not KeepsakeVfx.enabled():
			return
		_trail.push_front(before)
		if _trail.size() > 5:
			_trail.pop_back()
		queue_redraw()

	func _hit() -> void:
		if target.try_reflect(self):
			return   # it's now flying back at whoever fired it
		if _reflected:
			super()   # plain damage for its new owner
			return
		if on_hit.is_valid():
			on_hit.call(target)
		if bounces > 0 and _grid != null:
			# Its hero Ascension: on through the target, toward the edge.
			bounces -= 1
			_free_flight = true
			_free_dir = _heading if _heading != Vector2.ZERO else Vector2.UP
			return
		_after_hit()

	## Past its target: straight on to the board's edge, bounce once, then the first enemy
	## it passes takes the Gambit's hit. It fizzles at the next edge.
	func _fly_free(delta: float) -> void:
		var from := global_position
		var to := from + _free_dir * speed * speed_scale() * delta
		if _bounced:
			for node in get_tree().get_nodes_in_group("units"):
				var unit := node as BattleUnit
				if unit == null or not unit.alive or unit.team == team or not unit.is_targetable():
					continue
				var closest := Geometry2D.get_closest_point_to_segment(unit.global_position, from, to)
				if closest.distance_to(unit.global_position) > HIT_DISTANCE + 8.0:
					continue
				global_position = closest
				target = unit
				_free_flight = false
				_hit()   # reflectable, then the Gambit's hit
				if _free_flight == false and not is_queued_for_deletion() and not _reflected:
					_after_hit()
				return
		if not _grid.has_cell(_grid.world_to_cell(to)):
			if _bounced:
				queue_free()
				return
			_bounced = true
			_free_dir = SegBounceEffect.bounce_dir(_grid, from, _free_dir)
			_heading = _free_dir
			return
		global_position = to
		_heading = _free_dir

	func reflect(by: BattleUnit, wrack_chance: float, to: BattleUnit = null) -> bool:
		if not super(by, wrack_chance, to):
			return false
		_reflected = true
		on_hit = Callable()
		return true

	## A spinning white oval with a pale glow, and a faint trail behind it.
	func _draw() -> void:
		for i in _trail.size():
			var k := 1.0 - float(i) / _trail.size()
			draw_circle(to_local(_trail[i]), 3.0 * k, Color(SegFx.LIGHT, 0.4 * k))
		draw_colored_polygon(_oval(OVAL + Vector2(2.5, 2.5)), Color(SegFx.LIGHT, 0.35))
		draw_colored_polygon(_oval(OVAL), SegFx.COLOR)

	func _oval(radii: Vector2) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			points.append(Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(_spin))
		return points
