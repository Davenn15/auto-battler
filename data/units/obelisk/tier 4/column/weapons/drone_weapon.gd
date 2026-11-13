class_name ColumnDroneWeapon
extends ColumnWeapon
## B (Weaponized): sends out a homing drone that flies to the enemy with the lowest health
## (anywhere on the board) and explodes over it, damaging every enemy within Radius.
## Damage = Damage + Might Scaling x Might, fixed when launched.

@export var damage: float = 60.0
@export var might_scaling: float = 0.6
@export var radius_cells: int = 1
## Pixels per second.
@export var speed: float = 260.0


func fire(unit: BattleUnit) -> bool:
	var target: BattleUnit = null
	for node in unit.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not enemy.alive or enemy.team == unit.team or not enemy.is_targetable():
			continue
		if target == null or enemy.health < target.health:
			target = enemy
	if target == null:
		return false
	var drone := Drone.new()
	drone.target = target
	drone.speed = speed
	drone.radius_cells = radius_cells
	drone.hit = Stats.scaled(damage, might_scaling, unit.get_stat(Stats.Stat.MIGHT))
	drone.source_id = unit.get_instance_id()
	drone.credit_id = unit.get_credit_id()
	drone.team = unit.team
	drone.grid = unit.grid
	drone.z_index = 14
	unit.get_parent().add_child(drone)
	drone.global_position = unit.global_position + Vector2(0, -20)
	return true


## The drone: homes in on its target, keeps flying to where it last was if the target
## dies, then explodes. Independent of COLUMN, so it still lands if COLUMN dies.
class Drone extends Node2D:
	var target   # untyped: may be freed
	var speed := 260.0
	var radius_cells := 1
	var hit := 0.0
	var source_id := 0
	var credit_id := 0
	var team := 0
	var grid: BattleGrid
	var _goal := Vector2.ZERO
	var _time := 0.0
	var _arc := Arc.new()

	func _physics_process(delta: float) -> void:
		if is_instance_valid(target) and target.alive:
			_goal = target.global_position + Vector2(0, -12)   # just over its head
		elif _goal == Vector2.ZERO:
			queue_free()
			return
		if _arc.fly(self, _goal, speed, delta):
			_explode()

	func _explode() -> void:
		var center := grid.world_to_cell(global_position)
		var source := instance_from_id(source_id) as BattleUnit
		for node in get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy == null or not enemy.alive or enemy.team == team:
				continue
			if grid.get_distance(center, enemy.cell) <= radius_cells:
				var dealt := enemy.take_damage(hit, 0, Stats.DamageType.MIGHT, false, source)
				get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
		if KeepsakeVfx.enabled():
			KeepsakeVfx.missile_blast(get_parent(), global_position, (radius_cells + 0.5) * grid.cell_spacing(), ColumnWeapon.COLOR)
		queue_free()

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		ColumnDroneWeapon.draw_drone(self, _time)


## COLUMN's drone (also A2's Siphon drone): a small body with two spinning rotors, facing +x.
static func draw_drone(canvas: CanvasItem, time: float) -> void:
	canvas.draw_rect(Rect2(-5, -3, 10, 6), Color(0.25, 0.3, 0.2))
	canvas.draw_rect(Rect2(-5, -3, 10, 6), ColumnWeapon.COLOR, false, 1.0)
	for side in [-1, 1]:
		var hub := Vector2(0, side * 6)
		var blade := Vector2.from_angle(time * 30.0) * 5.0
		canvas.draw_line(hub - blade, hub + blade, Color(ColumnWeapon.LIGHT, 0.8), 1.5)
	canvas.draw_circle(Vector2(5, 0), 1.5, Color(1.0, 0.3, 0.2))


## A curved flight from where a drone starts to a (possibly moving) goal: a smooth arc that
## bows out to one side, so the drone always lands on the goal, near or far. Drones heading
## right of where they start bow one way, drones heading left the other; it's worked out
## from positions only, so it's the same on every machine. Start a new Arc for each trip.
class Arc extends RefCounted:
	## How far the arc bows out, as a share of the trip's length (0.5 = half as far out as
	## it is long).
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

	## Where along the arc a share `t` of the way is: a curve from the start to `goal` that
	## bends through a point off to the side of the halfway mark.
	func point(goal: Vector2, t: float) -> Vector2:
		var mid := (_start + goal) * 0.5
		var off := (goal - _start).orthogonal() * BOW * _side
		var control := mid - off
		return _start.lerp(control, t).lerp(control.lerp(goal, t), t)
