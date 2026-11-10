class_name BubbleShieldStatus
extends ShieldStatus
## A shield from one of Bubbler's Popping bubbles. When it breaks or runs out, the bubble
## pops, damaging (and with B1, stunning) every enemy next to the unit it was protecting.

var caster_id: int   # Bubbler; credited with the damage while he's alive
var team: int
var pop_damage: float
var pop_radius_cells: int
var pop_stun: float
var damage_type: int
var _popped := false
var _visual: Node2D


func _init(p_shield: float, p_duration: float) -> void:
	super(p_shield, p_duration)


func on_applied(unit: BattleUnit) -> void:
	super(unit)
	if KeepsakeVfx.enabled():
		_visual = BubbleShell.new()
		_visual.radius = KeepsakeVfx._sprite_size(unit).x * 0.6
		_visual.z_index = 11
		unit.add_child(_visual)


func on_removed(unit: BattleUnit) -> void:
	super(unit)
	if is_instance_valid(_visual):
		_visual.queue_free()


func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
	var left := super(unit, damage)
	if shield <= 0.0:
		_pop(unit)
	return left


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		_pop(unit)


func _pop(unit: BattleUnit) -> void:
	if _popped:
		return
	_popped = true
	unit.remove_status(self)
	KeepsakeVfx.burst(unit, BubbleZone.BUBBLE_COLOR)
	var caster: BattleUnit = instance_from_id(caster_id) as BattleUnit if is_instance_id_valid(caster_id) else null
	for node in unit.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not enemy.alive or enemy.team == team \
				or unit.grid.get_distance(unit.cell, enemy.cell) > pop_radius_cells:
			continue
		var dealt := enemy.take_damage(pop_damage, 0, damage_type, false, caster)
		unit.get_tree().call_group("damage_tracker", "record_damage", caster_id, dealt)
		if pop_stun > 0.0 and enemy.alive:
			enemy.stun(pop_stun, caster)


## A see-through bubble drawn around the protected unit.
class BubbleShell extends Node2D:
	var radius := 24.0
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		var r := radius * (1.0 + 0.04 * sin(time * 4.0))
		draw_circle(Vector2(0, -8), r, Color(BubbleZone.BUBBLE_COLOR, 0.12))
		draw_arc(Vector2(0, -8), r, 0.0, TAU, 40, Color(BubbleZone.BUBBLE_COLOR, 0.7), 1.5, true)
		draw_arc(Vector2(-r * 0.35, -8 - r * 0.35), r * 0.25, PI * 1.05, PI * 1.45, 10, Color(1, 1, 1, 0.5), 2.0, true)
