class_name ColumnBombWeapon
extends ColumnWeapon
## B (Weaponized): lobs an unstable matter bomb at the enemy with the lowest health
## (anywhere on the board). It arcs high over the board, following the enemy if it moves,
## and bursts on landing, damaging every enemy within Radius.
## Damage = Damage + Might Scaling x Might, fixed when lobbed.

@export var damage: float = 60.0
@export var might_scaling: float = 0.6
@export var radius_cells: int = 1
## Ground speed, pixels per second.
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
	var bomb := Bomb.new()
	bomb.target = target
	bomb.speed = speed
	bomb.radius_cells = radius_cells
	bomb.hit = Stats.scaled(damage, might_scaling, unit.get_stat(Stats.Stat.MIGHT))
	bomb.source_id = unit.get_instance_id()
	bomb.credit_id = unit.get_credit_id()
	bomb.team = unit.team
	bomb.grid = unit.grid
	bomb.z_index = 14
	unit.get_parent().add_child(bomb)
	bomb.start(unit.global_position + Vector2(0, -20))
	return true


## The bomb: a lob from COLUMN to its target (or where the target last was, if it dies),
## then a burst. Independent of COLUMN, so it still lands if COLUMN dies.
## Its node sits at the ground point under the bomb; the bomb itself is drawn `height`
## above that, with a shadow on the ground.
class Bomb extends Node2D:
	const ARC_HEIGHT := 0.45    # peak height as a share of the throw's length
	const MIN_PEAK := 40.0      # pixels: even a short lob goes up this far

	var target   # untyped: may be freed
	var speed := 260.0
	var radius_cells := 1
	var hit := 0.0
	var source_id := 0
	var credit_id := 0
	var team := 0
	var grid: BattleGrid
	var _from := Vector2.ZERO
	var _goal := Vector2.ZERO
	var _t := 0.0           # 0 at the throw, 1 on landing
	var _length := 1.0
	var height := 0.0
	var _time := 0.0        # crackle, on screen only

	func start(from: Vector2) -> void:
		_from = from
		global_position = from
		_aim()
		_length = maxf(_from.distance_to(_goal), 1.0)

	func _aim() -> void:
		if is_instance_valid(target) and target.alive:
			_goal = target.global_position

	func _physics_process(delta: float) -> void:
		_aim()
		_t = minf(_t + speed * delta / _length, 1.0)
		global_position = _from.lerp(_goal, _t)
		height = maxf(_length * ARC_HEIGHT, MIN_PEAK) * 4.0 * _t * (1.0 - _t)
		if _t >= 1.0:
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

	## A shadow on the ground that shrinks as the bomb climbs, and the bomb above it: a dark
	## core in a flickering lime shell with arcs of energy crackling off it.
	func _draw() -> void:
		var lift := clampf(height / 80.0, 0.0, 1.0)
		draw_circle(Vector2.ZERO, lerpf(6.0, 3.0, lift), Color(0, 0, 0, lerpf(0.35, 0.15, lift)))
		var at := Vector2(0, -height)
		var flicker := 0.5 + 0.5 * sin(_time * 25.0)
		draw_circle(at, 9.0 + flicker * 1.5, Color(ColumnWeapon.COLOR, 0.25))
		draw_circle(at, 6.0, Color(ColumnWeapon.COLOR, 0.9))
		draw_circle(at, 3.5, Color(0.08, 0.1, 0.06))
		draw_circle(at + Vector2(-1.5, -1.5), 1.2, Color(ColumnWeapon.LIGHT, 0.9))
		for i in 3:   # crackling arcs, jumping around each frame-ish
			var a := _time * 7.0 + i * TAU / 3.0 + sin(_time * 31.0 + i) * 0.8
			var p1 := at + Vector2.from_angle(a) * 6.0
			var p2 := at + Vector2.from_angle(a + 0.35) * 10.0
			var p3 := at + Vector2.from_angle(a - 0.1) * 13.0
			draw_polyline(PackedVector2Array([p1, p2, p3]), Color(ColumnWeapon.LIGHT, 0.85), 1.2, true)
