class_name ArcaneRing
extends Node2D
## A ring on the ground that deals damage to enemies inside it every tick, then explodes
## for a final burst that stuns everyone still inside. Everything it needs is copied in
## when it's cast, so it keeps going even if the caster dies.

const TICK_INTERVAL := 0.5   # seconds between damage ticks
const COLOR := Color(0.708, 0.094, 0.297, 1.0)   # violet

var caster_id: int
var team: int
var grid: BattleGrid
var center: Vector2i
var radius_cells: int
var tick_damage: float
var burst_damage: float
var stun_time: float
var damage_type: int
var _time_left: float
var _tick_timer: float = TICK_INTERVAL


func setup(p_caster: BattleUnit, p_center: Vector2i, p_radius_cells: int, p_duration: float,
		p_tick_damage: float, p_burst_damage: float, p_stun_time: float, p_type: int) -> void:
	caster_id = p_caster.get_instance_id()
	team = p_caster.team
	grid = p_caster.grid
	center = p_center
	radius_cells = p_radius_cells
	_time_left = p_duration
	tick_damage = p_tick_damage
	burst_damage = p_burst_damage
	stun_time = p_stun_time
	damage_type = p_type
	z_index = -1   # draw under the units


func _process(delta: float) -> void:
	_time_left -= delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer += TICK_INTERVAL
		for enemy in _enemies_inside():
			_damage(enemy, tick_damage)
	if _time_left <= 0.0:
		_explode()


func _explode() -> void:
	set_process(false)   # stop ticking; the fade below finishes the ring off
	for enemy in _enemies_inside():
		_damage(enemy, burst_damage)
		if enemy.alive:
			enemy.stun(stun_time)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)


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


func _damage(enemy: BattleUnit, amount: float) -> void:
	var dealt := enemy.take_damage(amount, false, damage_type)   # Gambit damage doesn't wrack
	get_tree().call_group("damage_tracker", "record_damage", caster_id, dealt)


func _draw() -> void:
	var r := (radius_cells + 0.5) * grid.cell_spacing()   # reaches the outer edge of the last cell
	draw_circle(Vector2.ZERO, r, Color(COLOR, 0.15))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, COLOR, 2.0)
