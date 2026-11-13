class_name ColumnSiphonWeapon
extends ColumnWeapon
## A2: sends a drone to the nearby enemy with the most health. It hovers over it and
## shines a green beam down for Channel Time, slowly draining Share of its max health (for
## the rest of combat), then flies back and heals COLUMN for everything it drained.
## If the enemy dies mid-drain, the drone comes back with what it has; if COLUMN dies, the
## drained health is lost.

## How far the enemy can be, in hex cells.
@export var range_cells: int = 3
## Share of the enemy's max health drained over the whole channel (0.06 = 6%).
@export_range(0.0, 1.0, 0.01) var share: float = 0.06
## Seconds the drone hovers over the enemy, draining.
@export var channel_time: float = 1.5
## Drone speed, pixels per second.
@export var speed: float = 240.0


func fire(unit: BattleUnit) -> bool:
	var victim: BattleUnit = null
	for enemy in ColumnWeapon.enemies_in_range(unit, range_cells):
		if victim == null or enemy.health > victim.health:
			victim = enemy
	if victim == null:
		return false
	var drone := SiphonDrone.new()
	drone.column = unit
	drone.victim = victim
	drone.total = victim.max_health * share
	drone.channel_time = maxf(channel_time, 0.1)
	drone.speed = speed
	drone.z_index = 14
	unit.get_parent().add_child(drone)
	drone.global_position = unit.global_position + SiphonDrone.HOVER
	return true


class SiphonDrone extends Node2D:
	enum Stage { OUT, DRAIN, BACK }
	const HOVER := Vector2(0, -30)   # how far above a unit's middle the drone hovers
	const TICK := 0.1

	var column   # untyped: either may be freed
	var victim
	var total := 0.0
	var channel_time := 1.5
	var speed := 240.0
	var drained := 0.0
	var _stage := Stage.OUT
	var _channel := 0.0
	var _tick := 0.0
	var _time := 0.0       # for the rotors and beam only (on screen)
	var _leg := -1         # which leg the curve was set up for (a Stage); -1 = none yet
	var _arc: ColumnDroneWeapon.Arc

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(column) or not column.alive:
			queue_free()   # COLUMN is gone: the drained health with it
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
				if _fly_to(column.global_position + HOVER, delta):
					if drained > 0.0:
						column.heal(drained, column.get_instance_id())
						if KeepsakeVfx.enabled():
							KeepsakeVfx.heal_flash(column)
					queue_free()

	## Takes `amount` off the victim's max health (and health, if it's above the new max).
	func _drain(amount: float) -> void:
		if amount <= 0.0:
			return
		var new_max: float = victim.max_health - amount
		victim.resize_health(new_max, minf(victim.health, new_max))
		drained += amount

	## Moves toward `goal` along a curved arc, like the B drone (ColumnDroneWeapon.Arc); each
	## leg (out to the victim, back to COLUMN) gets its own arc. True once there.
	func _fly_to(goal: Vector2, delta: float) -> bool:
		if _leg != _stage:   # a new leg: a new arc from here
			_leg = _stage
			_arc = ColumnDroneWeapon.Arc.new()
		return _arc.fly(self, goal, speed, delta)
		return false

	func _alive(unit) -> bool:
		return is_instance_valid(unit) and unit.alive

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if _stage == Stage.DRAIN:
			# A green UFO beam: a cone of light from the drone down over the enemy, with
			# rings rising up it as the health is pulled in.
			var down := (-HOVER).rotated(-rotation)   # straight down on screen, in the drone's own frame
			var side := down.orthogonal().normalized()
			var spread := 14.0
			var cone := PackedVector2Array([Vector2.ZERO + side * 3.0, Vector2.ZERO - side * 3.0,
					down - side * spread, down + side * spread])
			draw_colored_polygon(cone, Color(ColumnWeapon.COLOR, 0.28 + 0.08 * sin(_time * 12.0)))
			for ring in 3:
				var t := fposmod(_time * 1.6 + ring / 3.0, 1.0)
				var at := down * (1.0 - t)
				var w := lerpf(3.0, spread, 1.0 - t)
				draw_line(at - side * w, at + side * w, Color(ColumnWeapon.LIGHT, 0.7 * t), 2.0)
		ColumnDroneWeapon.draw_drone(self, _time)
		if drained > 0.0 and _stage == Stage.BACK:
			draw_circle(Vector2(-7, 0), 2.0 + minf(drained / 60.0, 3.0), Color(ColumnWeapon.LIGHT, 0.9))   # the stolen health
