class_name GeomondFx
extends RefCounted
## Geomond's effects, all drawn in code (placeholders, no art yet): the gold and stone rings
## of his shared shield and Wards, the mid-air spin before the slam, the slam line with
## cracks along it, the stone look of his rocky armor, the cracking seismic pulses, and the
## gold motes of a copied Shield or Ward. Nothing here changes gameplay.

const GOLD := Color(1.0, 0.82, 0.3)
const STONE := Color(0.62, 0.58, 0.5)
const STONE_LIGHT := Color(0.85, 0.82, 0.74)
const QUAKE := Color(0.79, 0.54, 0.29)
const CRACK := Color(0.23, 0.16, 0.1)


## A gold ring (the shield) and a dashed stone ring (the Wards) round `unit`, fading out.
static func rings(unit: BattleUnit) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(unit):
		return
	var node := Rings.new()
	node.radius = KeepsakeVfx._sprite_size(unit).length() * 0.42
	node.z_index = 11
	unit.add_child(node)


class Rings extends Node2D:
	var radius := 24.0
	var _age := 0.0
	const LIFE := 0.7

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _age / LIFE
		var fade := 1.0 - t
		var grow := 1.0 + 0.15 * t
		draw_arc(Vector2.ZERO, radius * grow, 0.0, TAU, 40, Color(GeomondFx.GOLD, 0.9 * fade), 3.0, true)
		for i in 16:
			var a := TAU * i / 16.0
			draw_arc(Vector2.ZERO, radius * grow + 6.0, a, a + TAU / 32.0, 4, Color(GeomondFx.STONE_LIGHT, 0.8 * fade), 2.0, true)


## The flip before the slam: his body turns a full circle in the air over `time` seconds.
## It turns the unit's MeleeMotion node, which nothing else turns. Await it.
static func spin(unit: BattleUnit, time: float) -> void:
	if KeepsakeVfx.enabled() and is_instance_valid(unit) and unit.melee_motion != null:
		var node := unit.melee_motion
		var tween := node.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(node, "rotation", TAU * (1.0 if randf() < 0.5 else -1.0), time) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): node.rotation = 0.0)
	await unit.get_tree().create_timer(time, true, true).timeout


## The slam: the line it hits flashes, with cracks along it, and fades.
static func slam_line(caster: BattleUnit, origin: Vector2, dir: Vector2, length: float, half_width: float) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(caster):
		return
	var node := SlamLine.new()
	node.length = length
	node.half_width = half_width
	node.rotation = dir.angle()
	node.z_index = 10
	caster.get_tree().current_scene.add_child(node)
	node.global_position = origin


class SlamLine extends Node2D:
	var length := 100.0
	var half_width := 20.0
	var _age := 0.0
	var _cracks: Array = []   # each a PackedVector2Array
	const LIFE := 0.55

	func _ready() -> void:
		var count := maxi(int(length / 26.0), 3)
		for i in count:
			var x := length * (i + 0.5) / count
			var points := PackedVector2Array()
			var y := -half_width * 0.8
			while y < half_width * 0.8:
				points.append(Vector2(x + randf_range(-6.0, 6.0), y))
				y += randf_range(6.0, 11.0)
			_cracks.append(points)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var fade := 1.0 - _age / LIFE
		var rect := Rect2(0, -half_width, length, half_width * 2.0)
		draw_rect(rect, Color(GeomondFx.QUAKE, 0.45 * fade))
		draw_rect(rect, Color(GeomondFx.GOLD, 0.6 * fade), false, 2.0)
		for points in _cracks:
			if points.size() > 1:
				draw_polyline(points, Color(GeomondFx.CRACK, 0.9 * fade), 2.0, true)


## Rocky armor on or off: a stone silhouette over his sprite with a pale rim.
const ARMOR_KEY := "VfxRockArmor"
const ARMOR_RIM_KEY := "VfxRockArmorRim"

static func armor(unit: BattleUnit, on: bool) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(unit) or unit.sprite == null:
		return
	var tint := KeepsakeVfx._sprite_copy(unit, ARMOR_KEY, "silhouette")
	(tint.material as ShaderMaterial).set_shader_parameter("tint", Color(STONE, 0.5))   # see-through, so he shows under it
	var rim := KeepsakeVfx._sprite_copy(unit, ARMOR_RIM_KEY, "outline", 3)
	(rim.material as ShaderMaterial).set_shader_parameter("tint", STONE_LIGHT)
	for node in [tint, rim]:
		node.texture = unit.sprite.texture
		node.offset = unit.sprite.offset
		node.flip_h = unit.sprite.flip_h
		node.visible = on
	tint.modulate.a = 0.55
	rim.modulate.a = 0.9


## A seismic pulse: a flash on the ground `radius` pixels round `unit`, cracks running out.
static func quake(unit: BattleUnit, radius: float) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(unit) or unit.grid == null:
		return
	var node := Quake.new()
	node.radius = radius
	KeepsakeVfx._ground(unit).add_child(node)
	node.global_position = unit.global_position


class Quake extends Node2D:
	var radius := 60.0
	var _age := 0.0
	var _angles: Array = []
	const LIFE := 0.4

	func _ready() -> void:
		for i in 8:
			_angles.append(TAU * i / 8.0 + randf_range(-0.25, 0.25))

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _age / LIFE
		var fade := 1.0 - t
		var squash := Vector2(1.0, 0.55)
		draw_set_transform(Vector2.ZERO, 0.0, squash)
		draw_circle(Vector2.ZERO, radius, Color(GeomondFx.QUAKE, 0.18 * fade))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(GeomondFx.QUAKE, 0.7 * fade), 2.0, true)
		var reach := radius * minf(t * 2.5, 1.0)
		for a in _angles:
			var dir := Vector2.from_angle(a)
			var mid := dir * reach * 0.5 + dir.orthogonal() * 4.0
			draw_polyline(PackedVector2Array([dir * 10.0, mid, dir * reach]), Color(GeomondFx.CRACK, 0.85 * fade), 2.0, true)
		draw_set_transform(Vector2.ZERO)


## B2: a few gold motes fly from `from` (an ally) to `to` (Geomond).
static func motes(from: BattleUnit, to: BattleUnit) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(from) or not is_instance_valid(to):
		return
	for i in 4:
		var mote := Mote.new()
		mote.target = to
		mote.delay = i * 0.06
		mote.z_index = 14
		from.get_tree().current_scene.add_child(mote)
		mote.global_position = from.global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-14.0, -2.0))


class Mote extends Node2D:
	const SPEED := 260.0
	var target   # untyped: may be freed
	var delay := 0.0

	func _process(delta: float) -> void:
		if not is_instance_valid(target):
			queue_free()
			return
		if delay > 0.0:
			delay -= delta
			return
		var goal: Vector2 = target.global_position + Vector2(0, -10)
		var to := goal - global_position
		if to.length() <= SPEED * delta:
			queue_free()
			return
		global_position += to.normalized() * SPEED * delta
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 5.0, Color(GeomondFx.GOLD, 0.3))
		draw_circle(Vector2.ZERO, 2.5, GeomondFx.GOLD)
