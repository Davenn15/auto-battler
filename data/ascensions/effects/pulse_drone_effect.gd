class_name PulseDroneEffect
extends Passive
## Controller's hero Ascension: the first time each combat it drops below Health Trigger of its
## max health, it launches a pulse drone that flies over the spot catching the most enemies
## and detonates: every enemy within Radius Cells is stunned for Stun seconds, and every
## ally there gains a Shield of Shield for Shield Duration seconds.

@export var health_trigger: float = 0.5
@export var radius_cells: int = 2
@export var stun: float = 1.0
@export var shield: float = 150.0
@export var shield_duration: float = 4.0

const SPEED := 260.0


func on_battle_start(unit: BattleUnit) -> void:
	var status := WatchStatus.new()
	status.effect = self
	unit.add_status(status)


class WatchStatus extends Status:
	var effect: PulseDroneEffect
	var used := false

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func tick(unit: BattleUnit, _delta: float) -> void:
		if used or not unit.alive or not unit.active or unit.max_health <= 0.0:
			return
		if unit.health / unit.max_health >= effect.health_trigger:
			return
		used = true
		var spot: Variant = _best_spot(unit)
		if spot == null:
			return
		var drone := PulseDrone.new()
		drone.effect = effect
		drone.owner_id = unit.get_instance_id()
		drone.team = unit.team
		drone.grid = unit.grid
		drone.target_cell = spot
		unit.get_parent().add_child(drone)
		drone.global_position = unit.global_position
		unit.show_float_text("Pulse Drone", CtrlDrones.LIGHT)

	## The enemy cell whose blast would catch the most enemies (nearest to Controller on ties),
	## or null if there are no enemies.
	func _best_spot(unit: BattleUnit) -> Variant:
		var enemies: Array = []
		for node in unit.get_tree().get_nodes_in_group("units"):
			var other := node as BattleUnit
			if other != null and other.alive and other.team != unit.team:
				enemies.append(other)
		var best: Variant = null
		var best_count := -1
		var best_distance := 0
		for center in enemies:
			var count := 0
			for other in enemies:
				if unit.grid.get_distance(center.cell, other.cell) <= effect.radius_cells:
					count += 1
			var distance: int = unit.grid.get_distance(unit.cell, center.cell)
			if count > best_count or (count == best_count and distance < best_distance):
				best = center.cell
				best_count = count
				best_distance = distance
		return best


## The drone: flies to its spot, hovers a moment, then bursts.
class PulseDrone extends Node2D:
	var effect: PulseDroneEffect
	var owner_id := 0
	var team := 0
	var grid: BattleGrid
	var target_cell := Vector2i.ZERO
	var _time := 0.0
	var _burst := -1.0   # >= 0 once it has burst: the ring's age

	func _ready() -> void:
		z_index = 20

	func _physics_process(delta: float) -> void:
		if _burst >= 0.0:
			return
		var goal := grid.cell_to_world(target_cell) + Vector2(0, -18)
		var to_goal := goal - global_position
		var step := PulseDroneEffect.SPEED * delta
		if to_goal.length() <= step:
			global_position = goal
			_detonate()
		else:
			global_position += to_goal.normalized() * step

	func _detonate() -> void:
		_burst = 0.0
		var source := instance_from_id(owner_id) as BattleUnit if is_instance_id_valid(owner_id) else null
		for node in get_tree().get_nodes_in_group("units"):
			var unit := node as BattleUnit
			if unit == null or not unit.alive or grid.get_distance(target_cell, unit.cell) > effect.radius_cells:
				continue
			if unit.team == team:
				unit.add_shield(effect.shield, effect.shield_duration, owner_id)
			else:
				unit.stun(effect.stun, source)

	func _process(delta: float) -> void:
		_time += delta
		if _burst >= 0.0:
			_burst += delta
			if _burst >= 0.45:
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		if _burst >= 0.0:
			var reach := (effect.radius_cells + 0.5) * grid.cell_spacing()
			var t := clampf(_burst / 0.45, 0.0, 1.0)
			draw_set_transform(Vector2(0, 18), 0.0, Vector2(1.0, 0.55))
			draw_circle(Vector2.ZERO, reach * t, Color(CtrlDrones.COLOR, 0.18 * (1.0 - t)))
			draw_arc(Vector2.ZERO, reach * t, 0.0, TAU, 48, Color(CtrlDrones.LIGHT, 0.9 * (1.0 - t)), 3.0, true)
			draw_set_transform(Vector2.ZERO)
			return
		# A small round drone with a blinking core and spinning rotor.
		draw_circle(Vector2.ZERO, 7.0, Color(0.16, 0.16, 0.18))
		draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 20, CtrlDrones.COLOR, 1.5, true)
		var blink := 0.5 + 0.5 * sin(_time * 18.0)
		draw_circle(Vector2.ZERO, 3.0, Color(CtrlDrones.LIGHT, 0.5 + 0.5 * blink))
		var spin := _time * 30.0
		draw_line(Vector2(0, -9) + Vector2.from_angle(spin) * 8.0, Vector2(0, -9) - Vector2.from_angle(spin) * 8.0, Color(0.85, 0.85, 0.9, 0.8), 1.5)
