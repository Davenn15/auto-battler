class_name SpinStatus
extends Status
## Glaive spinning like a sawblade: every Tick seconds he damages every enemy within Radius
## Cells. While spinning he can't attack or gain Charge, but he can still move.
##   B1: a chance to deflect each incoming shot back at its shooter.
##   B2: each spin hit leaves a bleed (see BleedStatus).

var time_left: float
var radius_cells: int
var tick_time: float
var damage: float
var damage_type: int
var deflect_chance: float
var bleed_percent: float      # share of the target's max health per second
var bleed_duration: float
var _tick_left := 0.0
var _visual: Node2D


func _init(p_duration: float, p_radius: int, p_tick: float, p_damage: float, p_type: int) -> void:
	time_left = p_duration
	radius_cells = p_radius
	tick_time = p_tick
	damage = p_damage
	damage_type = p_type


func on_applied(unit: BattleUnit) -> void:
	if KeepsakeVfx.enabled():
		_visual = SawRing.new()
		_visual.sprite = unit.sprite
		_visual.radius = (radius_cells + 0.3) * unit.grid.cell_spacing()
		_visual.z_index = -1
		unit.add_child(_visual)


func on_removed(_unit: BattleUnit) -> void:
	if is_instance_valid(_visual):
		_visual.queue_free()


func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return true


func try_reflect(unit: BattleUnit, projectile: Projectile) -> bool:
	if deflect_chance <= 0.0 or CombatRng.randf() >= deflect_chance:
		return false
	if not projectile.reflect(unit, unit.get_stat(Stats.Stat.WRACK_CHANCE)):
		return false
	unit.show_float_text("Deflect", GlaiveRotor.ROTOR_COLOR)
	return true


func tick(unit: BattleUnit, delta: float) -> void:
	unit._attack_timer = maxf(unit._attack_timer, 0.5)   # no attacking while spinning
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
		return
	if not unit.active:
		return
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left += tick_time
	var id := unit.get_credit_id()
	for node in unit.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not enemy.alive or enemy.team == unit.team or not enemy.is_targetable() \
				or unit.grid.get_distance(unit.cell, enemy.cell) > radius_cells:
			continue
		var dealt := enemy.take_damage(damage, 0, damage_type, false, unit)
		unit.get_tree().call_group("damage_tracker", "record_damage", id, dealt)
		if bleed_percent > 0.0 and dealt > 0.0 and enemy.alive:
			enemy.add_status(BleedStatus.new(id, bleed_percent * enemy.max_health, bleed_duration))


## A spinning toothed ring around Glaive, and Glaive himself spinning inside it.
class SawRing extends Node2D:
	const TEETH := 14
	const SPRITE_SPINS_PER_SECOND := 3.0
	var radius := 40.0
	var time := 0.0
	var sprite: Node2D   # Glaive's sprite, turned while he spins (only the look; his facing doesn't matter)

	func _process(delta: float) -> void:
		time += delta
		if is_instance_valid(sprite):
			sprite.rotation = time * TAU * SPRITE_SPINS_PER_SECOND
		queue_redraw()

	func _exit_tree() -> void:
		if is_instance_valid(sprite):
			sprite.rotation = 0.0   # upright again when the spin ends

	func _draw() -> void:
		var spin := time * 9.0
		var points := PackedVector2Array()
		for i in TEETH * 2 + 1:
			var a := TAU * i / (TEETH * 2) + spin
			var reach := radius * (1.0 if i % 2 == 0 else 0.86)
			points.append(Vector2.from_angle(a + (0.12 if i % 2 == 0 else 0.0)) * reach)
		draw_colored_polygon(points.slice(0, points.size() - 1), Color(GlaiveRotor.ROTOR_COLOR, 0.12))
		draw_polyline(points, Color(GlaiveRotor.ROTOR_COLOR, 0.85), 2.0, true)
