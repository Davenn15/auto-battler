class_name MortarUplinkEffect
extends Passive
## Barrage's hero Ascension: the first time each combat he plays his Gambit, a Mortar Drone
## appears in a free cell next to him. It's a normal summon that stays put for the rest of
## combat: Health Share of his max health, his Wards and Might (his base stats, buffs and
## levels included), never moves or attacks, and every Volley Interval seconds fires a
## volley of Volley Missiles of his Gambit's missiles (Barrage's homing missiles on A,
## Injector missiles on B) at Damage Share of their damage. Its attack bar shows the volley
## timer.

const PROFILE := preload("res://data/units/obelisk/tier 2/barraj/mortar_drone/mortar_drone.tres")
const UNIT_SCENE := preload("res://scenes/battle_unit.tscn")

@export var health_share: float = 0.3
@export var volley_interval: float = 5.0
@export var volley_missiles: int = 3
## 0.7 = 70% of his Gambit missiles' damage.
@export var damage_share: float = 0.7


func on_battle_start(unit: BattleUnit) -> void:
	var status := UplinkStatus.new()
	status.effect = self
	unit.add_status(status)


## On Barrage: spawns the drone on his first play.
class UplinkStatus extends Status:
	var effect: MortarUplinkEffect
	var spawned := false

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_played(unit: BattleUnit) -> void:
		if spawned or unit.gambit == null or not ("missiles" in unit.gambit):
			return
		spawned = true
		var cell: Variant = _free_cell(unit)
		if cell == null:
			return
		var drone := UNIT_SCENE.instantiate() as BattleUnit
		drone.setup_as_profile_summon(PROFILE, unit, effect.health_share)
		unit.get_parent().add_child(drone)
		drone.place_at(cell)
		unit.get_tree().call_group("battle_manager", "add_summon", drone)
		if not is_instance_valid(drone) or drone.is_queued_for_deletion():
			return
		# After add_summon (start_combat clears statuses).
		var volley := unit.gambit.duplicate() as Gambit
		volley.missiles = effect.volley_missiles
		volley.damage *= effect.damage_share
		volley.might_scaling *= effect.damage_share
		drone.add_status(MortarStatus.new(volley, effect.volley_interval))
		KeepsakeVfx.missile_blast(unit.get_parent(), drone.global_position, 30.0, BarrageMissile.COLOR)
		drone.show_float_text("Mortar Drone", BarrageMissile.COLOR)

	## A free cell next to `unit`, else within 2 or 3 cells; null if there's none.
	func _free_cell(unit: BattleUnit) -> Variant:
		for reach in [1, 2, 3]:
			var cells := unit.grid.free_cells_in_range(unit.cell, reach)
			if not cells.is_empty():
				cells.sort_custom(func(a, b): return unit.grid.get_distance(unit.cell, a) < unit.grid.get_distance(unit.cell, b))
				return cells[0]
		return null


## On the drone: never moves or attacks; fires a volley every Interval seconds (it waits,
## bar full, while no enemy is in reach).
class MortarStatus extends Status:
	var volley: Gambit
	var interval: float
	var _left: float
	var _look: DroneLook

	func _init(p_volley: Gambit, p_interval: float) -> void:
		volley = p_volley
		interval = p_interval
		_left = p_interval

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func blocks_attacks(_unit: BattleUnit) -> bool:
		return true

	func blocks_movement(_unit: BattleUnit) -> bool:
		return true

	func on_applied(unit: BattleUnit) -> void:
		if KeepsakeVfx.enabled():
			if unit.sprite != null:
				unit.sprite.visible = false
			_look = DroneLook.new()
			_look.z_index = 1
			unit.add_child(_look)

	func modify_attack_bar(_unit: BattleUnit, _value: float) -> float:
		return clampf(1.0 - _left / interval, 0.0, 1.0)

	func tick(unit: BattleUnit, delta: float) -> void:
		unit._attack_timer = maxf(unit._attack_timer, 1.0)   # it never attacks
		if not unit.active or not unit.alive:
			return
		_left = maxf(_left - delta, 0.0)
		if _left > 0.0 or not volley.can_use(unit):
			return
		_left = interval
		volley.execute(unit)
		if is_instance_valid(_look):
			_look.recoil()


## A placeholder look, drawn in code (no art yet): a small hovering drone with a mortar tube
## and spinning rotors, in Barrage's missile colour.
class DroneLook extends Node2D:
	const BODY := Color(0.28, 0.3, 0.36)
	const TRIM := Color(1.0, 0.55, 0.2)
	var _time := 0.0
	var _kick := 0.0

	func recoil() -> void:
		_kick = 1.0

	func _process(delta: float) -> void:
		_time += delta
		_kick = maxf(0.0, _kick - delta * 4.0)
		queue_redraw()

	func _draw() -> void:
		var bob := sin(_time * 3.0) * 2.0
		# Shadow on the ground.
		draw_set_transform(Vector2(0, 16), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2(0, bob - 4.0))
		# Rotor arms and spinning blades.
		for side in [-1.0, 1.0]:
			var hub: Vector2 = Vector2(side * 15.0, -6.0)
			draw_line(Vector2(side * 6.0, -2.0), hub, BODY, 3.0)
			var spin: float = _time * 24.0 * side
			draw_line(hub + Vector2.from_angle(spin) * 8.0, hub - Vector2.from_angle(spin) * 8.0, Color(0.85, 0.85, 0.9, 0.7), 1.5)
			draw_circle(hub, 2.0, BODY)
		# Body.
		var body := PackedVector2Array()
		for i in 6:
			body.append(Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * 9.0)
		draw_colored_polygon(body, BODY)
		draw_polyline(body + PackedVector2Array([body[0]]), TRIM, 1.5)
		# Mortar tube, angled up, kicking back when it fires.
		var tube_base := Vector2(0, -4.0 + _kick * 3.0)
		draw_line(tube_base, tube_base + Vector2(4.0, -11.0), Color(0.18, 0.19, 0.22), 5.0)
		draw_circle(tube_base + Vector2(4.0, -11.0), 2.5, TRIM if _kick > 0.0 else Color(0.4, 0.4, 0.45))
		draw_circle(Vector2.ZERO, 3.0, TRIM)
		draw_set_transform(Vector2.ZERO)
