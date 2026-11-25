class_name ByteFx
extends RefCounted
## Byte's look: deep blue.

const COLOR := Color(0.1, 0.22, 0.72)    # deep blue
const LIGHT := Color(0.42, 0.6, 1.0)


## The concussive ripple: rings spreading out on the ground under `target`.
static func ripple(target: BattleUnit) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(target):
		return
	var rings := Ripple.new()
	KeepsakeVfx._ground(target).add_child(rings)
	rings.global_position = target.global_position


## Buffeting: a wedge flashing out from `caster` along `aim` (radians, on screen),
## `reach` pixels long and `half_angle` radians either side.
static func cone(caster: BattleUnit, aim: float, reach: float, half_angle: float) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(caster):
		return
	var wedge := Wedge.new()
	wedge.aim = aim
	wedge.reach = reach
	wedge.half_angle = half_angle
	wedge.z_index = 8
	caster.get_tree().current_scene.add_child(wedge)
	wedge.global_position = caster.global_position


## B2: a small healing orb flying from `from` to `ally`.
static func splash(from: Vector2, ally: BattleUnit) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(ally):
		return
	var orb := Orb.new()
	orb.target = ally
	orb.z_index = 12
	ally.get_tree().current_scene.add_child(orb)
	orb.global_position = from


class Ripple extends Node2D:
	const TIME := 0.5
	const RADIUS := 34.0
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= TIME:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _age / TIME
		for i in 3:
			var k := clampf(t * 1.6 - i * 0.3, 0.0, 1.0)
			if k <= 0.0 or k >= 1.0:
				continue
			var fade := 1.0 - k
			draw_arc(Vector2.ZERO, RADIUS * k, 0.0, TAU, 40, Color(ByteFx.LIGHT, 0.9 * fade), 3.0 * fade + 1.0, true)
		draw_circle(Vector2.ZERO, RADIUS * 0.35 * (1.0 - t), Color(ByteFx.COLOR, 0.5 * (1.0 - t)))


class Wedge extends Node2D:
	const TIME := 0.35
	var aim := 0.0
	var reach := 80.0
	var half_angle := 0.8
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= TIME:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _age / TIME
		var r := reach * (0.4 + 0.6 * minf(t * 2.0, 1.0))
		var points := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			var a := aim - half_angle + 2.0 * half_angle * i / 12.0
			points.append(Vector2.from_angle(a) * r)
		var fade := 1.0 - t
		draw_colored_polygon(points, Color(ByteFx.COLOR, 0.35 * fade))
		draw_polyline(points.slice(1), Color(ByteFx.LIGHT, 0.85 * fade), 2.5, true)


class Orb extends Node2D:
	const SPEED := 420.0
	var target   # untyped: may be freed

	func _process(delta: float) -> void:
		if not is_instance_valid(target) or not target.alive:
			queue_free()
			return
		var to: Vector2 = target.global_position - global_position
		if to.length() <= SPEED * delta:
			queue_free()
			return
		global_position += to.normalized() * SPEED * delta
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 6.0, Color(ByteFx.LIGHT, 0.35))
		draw_circle(Vector2.ZERO, 3.5, Color(0.6, 1.0, 0.75))


# ---------- Hard Shell: a thin see-through deep blue layer over Byte ----------

const SHELL_KEY := "ByteShell"
const SHELL_MARGIN := 3          # pixels the copy grows past the texture, room for the rim
const SHELL_FILL := Color(0.06, 0.16, 0.75, 0.4)
const SHELL_RIM := Color(0.18, 0.35, 0.95, 0.8)
const SHELL_SHADER := """
shader_type canvas_item;
uniform vec4 fill : source_color;
uniform vec4 rim : source_color;
uniform float width = 0.8;
float alpha_at(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { return 0.0; }
	return texture(tex, uv).a;
}
void fragment() {
	vec2 step_size = TEXTURE_PIXEL_SIZE * width;
	float self = alpha_at(TEXTURE, UV);
	float near = 0.0;
	float inner = 1.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		float a = alpha_at(TEXTURE, UV + vec2(cos(angle), sin(angle)) * step_size);
		near = max(near, a);
		inner = min(inner, a);
	}
	float edge = max(clamp(near - self, 0.0, 1.0), clamp(self - inner, 0.0, 1.0));
	float sheen = 0.5 + 0.5 * sin((UV.x + UV.y) * 9.0 - TIME * 1.6);
	float body = step(0.5, self) * fill.a * (0.75 + 0.35 * sheen);
	vec3 color = mix(fill.rgb, rim.rgb, edge);
	COLOR = vec4(color, max(body, edge * rim.a));
}
"""
static var _shell_shader: Shader


## Puts the shell on `unit` (on), or takes it off (off). `animate`: it shatters into shards
## as it breaks, and snaps back together as it reforges; otherwise it just appears.
static func shell(unit: BattleUnit, on: bool, animate: bool) -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(unit) or unit.sprite == null:
		return
	var node := _shell_node(unit)
	if node == null:
		return
	var old = node.get_meta("tween") if node.has_meta("tween") else null
	if old is Tween and old.is_valid():
		old.kill()
	node.scale = Vector2.ONE
	if not animate:
		node.visible = on
		node.modulate.a = 1.0
		return
	var tween := node.create_tween()
	node.set_meta("tween", tween)
	if on:
		# Reforge: the shell closes in from a little wider, flashing bright as it seals.
		node.visible = true
		node.modulate = Color(2.0, 2.0, 2.0, 0.0)
		node.scale = Vector2.ONE * 1.35
		tween.set_parallel()
		tween.tween_property(node, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "modulate:a", 1.0, 0.2)
		tween.chain().tween_property(node, "modulate", Color.WHITE, 0.25)
		_shards(unit, false)
	else:
		# Break: a bright crack, then the pieces fly off.
		node.modulate = Color(2.2, 2.2, 2.2, 1.0)
		tween.tween_property(node, "modulate", Color(1, 1, 1, 0.0), 0.12)
		tween.tween_callback(func(): node.visible = false)
		_shards(unit, true)


static func _shell_node(unit: BattleUnit) -> Sprite2D:
	var node := unit.sprite.get_node_or_null(SHELL_KEY) as Sprite2D
	if node != null:
		node.flip_h = unit.sprite.flip_h   # follow the sprite if it turned
		return node
	if unit.sprite.texture == null:
		return null
	if _shell_shader == null:
		_shell_shader = Shader.new()
		_shell_shader.code = SHELL_SHADER
	node = Sprite2D.new()
	node.name = SHELL_KEY
	node.texture = unit.sprite.texture
	node.offset = unit.sprite.offset
	node.flip_h = unit.sprite.flip_h
	node.region_enabled = true
	node.region_rect = Rect2(Vector2(-SHELL_MARGIN, -SHELL_MARGIN), node.texture.get_size() + Vector2(SHELL_MARGIN, SHELL_MARGIN) * 2)
	var material := ShaderMaterial.new()
	material.shader = _shell_shader
	material.set_shader_parameter("fill", SHELL_FILL)
	material.set_shader_parameter("rim", SHELL_RIM)
	node.material = material
	unit.sprite.add_child(node)
	return node


## Shell pieces: flying out from Byte when it breaks (`out`), or flying in when it reforges.
static func _shards(unit: BattleUnit, out: bool) -> void:
	var burst := Shards.new()
	burst.out = out
	burst.radius = KeepsakeVfx._sprite_size(unit).length() * 0.32
	burst.z_index = 9
	unit.get_tree().current_scene.add_child(burst)
	burst.global_position = unit.global_position


class Shards extends Node2D:
	const COUNT := 12
	var out := true
	var radius := 22.0
	var _time := 0.5
	var _age := 0.0
	var _pieces: Array = []   # [angle, distance, spin, size]

	func _ready() -> void:
		_time = 0.5 if out else 0.28
		for i in COUNT:
			var angle := TAU * i / COUNT + randf_range(-0.2, 0.2)
			_pieces.append([angle, randf_range(0.6, 1.0), randf_range(-8.0, 8.0), randf_range(2.5, 4.5)])

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _time:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t := _age / _time
		# Breaking pieces start on the shell and fly out; reforging ones come in to it.
		var k := t if out else 1.0 - t
		var ease := 1.0 - pow(1.0 - k, 2.0) if out else k
		var fade := 1.0 - t if out else minf(t * 3.0, 1.0) * (1.0 - t * 0.5)
		for piece in _pieces:
			var dir := Vector2.from_angle(piece[0])
			var center: Vector2 = dir * radius * (piece[1] + ease * 0.9)
			if out:
				center.y += 24.0 * t * t   # they fall a little
			var spin: float = piece[2] * k
			var size: float = piece[3]
			var points := PackedVector2Array()
			for corner in [Vector2(0, -size), Vector2(size * 0.8, size * 0.6), Vector2(-size * 0.7, size * 0.5)]:
				points.append(center + corner.rotated(spin + piece[0]))
			draw_colored_polygon(points, Color(ByteFx.COLOR, 0.65 * fade))
			points.append(points[0])
			draw_polyline(points, Color(ByteFx.LIGHT, 0.95 * fade), 1.2, true)
