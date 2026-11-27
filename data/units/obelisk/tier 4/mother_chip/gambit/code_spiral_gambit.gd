class_name CodeSpiralGambit
extends Gambit
## Mother-Chip calls down a corrupted code spiral: a circle on the ground, centred on the
## cell within her attack range that covers the most enemies. For Duration seconds, every
## enemy inside it gets Stacks Per Second Mono-Virus stacks each second, and takes
## Damage + Insight Scaling x her Insight as Insight damage every Damage Interval seconds
## (Gambit damage, sized when she casts it). It stays where it landed, and keeps going if
## she dies. She can't gain Charge while it lasts.

@export var radius_cells: int = 1
@export var duration: float = 5.0
@export var stacks_per_second: int = 1
@export var damage: float = 60.0
@export var insight_scaling: float = 0.3
## Seconds between damage ticks.
@export var damage_interval: float = 0.5


func can_use(caster: BattleUnit) -> bool:
	return _best_center(caster) != Vector2i(-999, -999)


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive or not caster.is_inside_tree():
		return
	var center := _best_center(caster)
	if center == Vector2i(-999, -999):
		return
	var spiral := CodeSpiral.new()
	spiral.grid = caster.grid
	spiral.center = center
	spiral.team = caster.team
	spiral.credit_id = caster.get_credit_id()
	spiral.caster_id = caster.get_instance_id()
	spiral.radius_cells = radius_cells
	spiral.time_left = duration
	spiral.duration = duration
	spiral.stacks = stacks_per_second
	spiral.hit = Stats.scaled(damage, insight_scaling, caster.get_stat(Stats.Stat.INSIGHT))
	spiral.damage_interval = maxf(damage_interval, 0.05)
	spiral.z_index = -1   # on the ground, under the units
	caster.get_parent().add_child(spiral)
	spiral.global_position = caster.grid.cell_to_world(center)
	caster.show_float_text("Code Spiral", ChipPassive.LIGHT)
	caster.add_status(SpiralChargeLock.new(duration))   # no Charge while it lasts


## On Mother-Chip while her spiral lasts: she can't gain Charge.
class SpiralChargeLock extends Status:
	var time_left: float

	func _init(p_duration: float) -> void:
		time_left = p_duration

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return true

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			unit.remove_status(self)


## The cell within her range whose circle covers the most enemies (nearest to her on ties),
## or (-999, -999) if no enemy is in reach of any.
func _best_center(caster: BattleUnit) -> Vector2i:
	var enemies: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team and unit.is_targetable():
			enemies.append(unit)
	var best := Vector2i(-999, -999)
	var best_count := 0
	var best_distance := 999
	for cell in caster.grid.all_cells():
		var distance := caster.grid.get_distance(caster.cell, cell)
		if distance > caster.attack_range:
			continue
		var count := 0
		for enemy in enemies:
			if caster.grid.get_distance(cell, enemy.cell) <= radius_cells:
				count += 1
		if count > best_count or (count == best_count and count > 0 and distance < best_distance):
			best = cell
			best_count = count
			best_distance = distance
	return best


## The spiral on the ground: gameplay ticks once a second, drawn as a UFO beam of light
## coming down with corrupted code swirling round it.
class CodeSpiral extends Node2D:
	var grid: BattleGrid
	var center: Vector2i
	var team := 0
	var credit_id := 0
	var caster_id := 0   # Mother-Chip herself (her hero Ascension's knock-up)
	var radius_cells := 1
	var time_left := 5.0
	var duration := 5.0
	var stacks := 1
	var hit := 0.0                 # Insight damage per damage tick
	var damage_interval := 0.5
	var _damage_tick := 0.5
	var _tick := 1.0
	var _time := 0.0
	var _fading := false
	var _cell_cache: Array = []

	func _physics_process(delta: float) -> void:
		if _fading:
			return
		time_left -= delta
		_damage_tick -= delta
		if _damage_tick <= 0.0 and hit > 0.0:
			_damage_tick += damage_interval
			_deal_damage()
		_tick -= delta
		if _tick <= 0.0:
			_tick += 1.0
			for node in get_tree().get_nodes_in_group("units"):
				var unit := node as BattleUnit
				if unit != null and unit.alive and unit.active and unit.team != team \
						and grid.get_distance(center, unit.cell) <= radius_cells:
					MonoVirusStatus.infect(unit, stacks, credit_id)
					CodeShockEffect.touch(caster_id, unit)
		if time_left <= 0.0:
			_fading = true
			var tween := create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 0.35)
			tween.tween_callback(queue_free)

	## One damage tick to every enemy inside: Gambit damage credited to Mother-Chip (it
	## can Wrack if she's alive to roll it).
	func _deal_damage() -> void:
		var caster: BattleUnit = null   # null once she's gone: the damage keeps going without her
		if caster_id != 0:
			caster = instance_from_id(caster_id) as BattleUnit
		for node in get_tree().get_nodes_in_group("units"):
			var unit := node as BattleUnit
			if unit == null or not unit.alive or not unit.active or unit.team == team \
					or grid.get_distance(center, unit.cell) > radius_cells:
				continue
			var level := 0
			var amount := hit
			if caster != null and caster.alive:
				level = caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
				amount *= caster.effect_wrack_multiplier(level, Stats.EffectKind.GAMBIT_DAMAGE)
			var dealt := unit.take_damage(amount, level, Stats.DamageType.INSIGHT, false, caster, false)
			unit.add_running_damage("code_spiral", dealt, Stats.damage_color(Stats.DamageType.INSIGHT, level), level)
			if caster != null:
				BattleUnit.gambit_damage_dealt(caster, unit, dealt)
			get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _noise(a: float, b: float) -> float:
		return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)

	func _draw() -> void:
		var r := (radius_cells + 0.5) * grid.cell_spacing()
		var inner := radius_cells * grid.cell_spacing()   # the code stays inside the hit cells
		var appear := minf((duration - time_left) / 0.3, 1.0)
		var pulse := 0.85 + 0.15 * sin(_time * 6.0)
		# The beam: a cone of light from high above down to the circle.
		var top_y := -r * 2.2
		var top_w := r * 0.25
		var cone := PackedVector2Array([Vector2(-top_w, top_y), Vector2(top_w, top_y), Vector2(r, 0), Vector2(-r, 0)])
		draw_colored_polygon(cone, Color(ChipPassive.COLOR, 0.13 * appear * pulse))
		draw_line(Vector2(-top_w, top_y), Vector2(-r, 0), Color(ChipPassive.LIGHT, 0.35 * appear), 1.5, true)
		draw_line(Vector2(top_w, top_y), Vector2(r, 0), Color(ChipPassive.LIGHT, 0.35 * appear), 1.5, true)
		# The pool of light on the ground: exactly the cells it hits (every cell within
		# Radius Cells of its centre), so the shape matches what it does.
		for cell in _cells():
			var hexagon := PackedVector2Array()
			for corner in grid.hex_corners_world(cell):
				hexagon.append(to_local(corner))
			draw_colored_polygon(hexagon, Color(ChipPassive.COLOR, 0.22 * appear * pulse))
			hexagon.append(hexagon[0])
			draw_polyline(hexagon, Color(ChipPassive.LIGHT, 0.8 * appear), 1.5, true)
		# Rings of light sliding down the beam, like a tractor beam.
		for k in 3:
			var t := fposmod(_time * 0.8 + k / 3.0, 1.0)
			var y := lerpf(top_y, 0.0, t)
			var w := lerpf(top_w, r, t)
			var band := PackedVector2Array()
			for i in 25:
				band.append(Vector2(cos(TAU * i / 24.0) * w, y + sin(TAU * i / 24.0) * w * 0.55 * 0.4))
			draw_polyline(band, Color(ChipPassive.LIGHT, 0.4 * appear * (1.0 - absf(t - 0.5))), 1.5, true)
		# The code spiral: bits of glitchy code swirling inward on the ground.
		var tick := floorf(_time * 10.0)
		for arm in 3:
			for i in 14:
				var along := float(i) / 14.0
				var angle := _time * 2.2 + arm * TAU / 3.0 + along * 5.0
				var at := Vector2.from_angle(angle) * inner * (1.0 - along * 0.85)
				if _noise(arm * 31.0 + i, tick) < 0.2:
					continue
				var w := 2.0 + 4.0 * _noise(i + arm, tick + 1.0)
				draw_rect(Rect2(at - Vector2(w * 0.5, 1.0), Vector2(w, 2.0)), Color(ChipPassive.LIGHT, 0.8 * appear))

	## Every cell within Radius Cells of the centre: the cells it hits.
	func _cells() -> Array:
		if _cell_cache.is_empty():
			for cell in grid.all_cells():
				if grid.get_distance(center, cell) <= radius_cells:
					_cell_cache.append(cell)
		return _cell_cache
