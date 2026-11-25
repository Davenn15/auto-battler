class_name ColumnMissileWeapon
extends ColumnWeapon
## Column's hero Ascension: a new weapon (on its own timer, like its others). It launches
## Missiles seeking missiles into the air, where they spend Triangulate seconds picking
## their targets (lines show what they're locking onto), then dive at the lowest-health
## enemies in its attack range, each at a different one when it can. Each deals Damage +
## Might Scaling x Might, fixed at launch.

@export var missiles: int = 5
@export var triangulate: float = 2.0
@export var damage: float = 90.0
@export var might_scaling: float = 0.5


func fire(unit: BattleUnit) -> bool:
	if enemies_in_range(unit, unit.attack_range).is_empty():
		return false
	var swarm := Swarm.new()
	swarm.source_id = unit.get_instance_id()
	swarm.credit_id = unit.get_credit_id()
	swarm.team = unit.team
	swarm.grid = unit.grid
	swarm.home_cell = unit.cell
	swarm.range_cells = unit.attack_range
	swarm.hit = Stats.scaled(damage, might_scaling, unit.get_stat(Stats.Stat.MIGHT))
	swarm.damage_type = unit.get_attack_damage_type()
	swarm.triangulate = triangulate
	swarm.count = missiles
	unit.get_parent().add_child(swarm)
	swarm.start(unit.global_position)
	return true


## All of one launch's missiles: up, hover while triangulating, then dive. Independent of
## Column, so they still land if it dies.
class Swarm extends Node2D:
	const RISE := 0.35
	const SPEED := 420.0
	const HIT_DISTANCE := 10.0
	var source_id := 0
	var credit_id := 0
	var team := 0
	var grid: BattleGrid
	var home_cell := Vector2i.ZERO
	var range_cells := 5
	var hit := 0.0
	var damage_type := 0
	var triangulate := 2.0
	var count := 5
	var _origin := Vector2.ZERO
	var _missiles: Array = []   # {pos, slot, target, done, heading}
	var _time := 0.0
	var _diving := false

	func start(origin: Vector2) -> void:
		top_level = true
		global_position = Vector2.ZERO
		z_index = 15
		_origin = origin + Vector2(0, -16)
		for i in count:
			var slot := _origin + Vector2((i - (count - 1) / 2.0) * 13.0, -58.0 - absf(i - (count - 1) / 2.0) * -4.0)
			_missiles.append({"pos": _origin, "slot": slot, "target": null, "done": false, "heading": Vector2.UP})

	## The lowest-health enemies in range of where Column fired from (anywhere, if none are
	## left in range), lowest first.
	func _candidates() -> Array:
		var in_range: Array = []
		var anywhere: Array = []
		for node in get_tree().get_nodes_in_group("units"):
			var unit := node as BattleUnit
			if unit == null or not unit.alive or unit.team == team or not unit.is_targetable():
				continue
			anywhere.append(unit)
			if grid.get_distance(home_cell, unit.cell) <= range_cells:
				in_range.append(unit)
		var list := in_range if not in_range.is_empty() else anywhere
		list.sort_custom(func(a, b): return a.health < b.health)
		return list

	func _physics_process(delta: float) -> void:
		_time += delta
		if not _diving:
			var rise := clampf(_time / RISE, 0.0, 1.0)
			for m in _missiles:
				m["pos"] = _origin.lerp(m["slot"], 1.0 - pow(1.0 - rise, 2.0)) + Vector2(0, sin(_time * 6.0 + m["slot"].x) * 1.5)
			if _time >= RISE + triangulate:
				_diving = true
				var targets := _candidates()
				for i in _missiles.size():
					_missiles[i]["target"] = targets[i % targets.size()] if not targets.is_empty() else null
			return
		var left := 0
		for m in _missiles:
			if m["done"]:
				continue
			var target = m["target"]
			if not is_instance_valid(target) or not target.alive:
				var next := _candidates()
				if next.is_empty():
					m["done"] = true
					continue
				target = next[0]
				m["target"] = target
			var to_target: Vector2 = target.global_position - m["pos"]
			if to_target.length() <= HIT_DISTANCE + SPEED * delta:
				m["done"] = true
				_hit(target)
				KeepsakeVfx.burst(target, ColumnWeapon.COLOR)
				continue
			m["heading"] = to_target.normalized()
			m["pos"] += m["heading"] * SPEED * delta
			left += 1
		if left == 0:
			queue_free()

	func _hit(target: BattleUnit) -> void:
		var source := instance_from_id(source_id) as BattleUnit if is_instance_id_valid(source_id) else null
		var dealt := target.take_damage(BattleUnit.damage_bonus(credit_id, target, hit), 0, damage_type, false, source)
		get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var lock: Array = [] if _diving else _candidates()
		for i in _missiles.size():
			var m: Dictionary = _missiles[i]
			if m["done"]:
				continue
			var pos: Vector2 = m["pos"]
			# Triangulating: a faint line to what it's locking onto, steadier as time runs out.
			if not _diving and not lock.is_empty() and _time > RISE:
				var aim: BattleUnit = lock[i % lock.size()]
				var sure := clampf((_time - RISE) / triangulate, 0.0, 1.0)
				var flicker := 0.5 + 0.5 * sin(_time * 20.0 + i)
				draw_line(pos, aim.global_position, Color(ColumnWeapon.COLOR, (0.08 + 0.25 * sure) * flicker), 1.0)
			var heading: Vector2 = m["heading"]
			var tail := pos - heading * 9.0
			draw_line(tail, pos, Color(0.85, 0.87, 0.9), 3.0)
			draw_circle(pos, 2.0, ColumnWeapon.LIGHT)
			draw_line(tail, tail - heading * (6.0 if _diving else 3.0), Color(1.0, 0.7, 0.3, 0.8), 2.0)
