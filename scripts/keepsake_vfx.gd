class_name KeepsakeVfx
extends RefCounted
## Placeholder visuals for keepsake effects, so it's easy to see when they proc. Every
## function is static: keepsake effects call them, e.g. KeepsakeVfx.burst(target, color).
## Nothing here changes gameplay. In the headless balance sim they all do nothing, so the
## sim stays fast.

const GHOST_TINT := Color(0.75, 0.9, 1.0, 0.55)
const GHOST_OFFSET := 12.0        # pixels behind the unit, away from the target
const GHOST_DELAY := 0.07         # seconds after the real attack that the ghost swings
const KILL_GLOW := Color(1.0, 0.25, 0.2)
const INSIGHT_GLOW := Color(0.3, 0.55, 1.0)
const LAST_CHANCE_GLOW := Color(1.0, 0.1, 0.1)
const PHASE_TINT := Color(0.45, 0.75, 1.6, 0.75)   # over 1 brightens; see-through while untargetable
const HEAL_OUTLINE := Color(0.35, 1.0, 0.45)
const WIND_COLOR := Color(1.0, 0.9, 0.35, 0.55)
const WARD_CIRCLE_COLOR := Color(1.0, 0.2, 0.15)
const SNOW_COLOR := Color(0.85, 0.95, 1.0)
const DIM_COLOR := Color(0.2, 0.8, 0.75)
const RALLY_COLOR := Color(1.0, 0.6, 0.2)        # Lunck's aura
const RALLY_INSIGHT_COLOR := Color(0.35, 0.6, 1.0)  # Lunck's aura once it also gives Insight
const RALLY_STRENGTH := 0.45   # Lunck's aura is drawn fainter than the keepsake auras
const BELLOW_RING_COLOR := Color(1.0, 0.18, 0.12)  # Merribold's Bellow
const LUNCK_ORANGE := Color(1.0, 0.55, 0.15)       # Lunck's flag and heart
const CRESCENDO_COLOR := Color(1.0, 0.5, 0.8)      # Prancelot's floating notes
const BREMES_TEAL := Color(0.25, 0.85, 0.8)        # Bremes' slash and smoke
const LORDRED_RED := Color(1.0, 0.28, 0.45)        # Lordred's cleave and taunt
const HEAD_ICON_HEIGHT := -66.0                     # above the health bar and item icons
const BURST_COLOR := Color(0.35, 0.6, 1.0)
const SPARK_COLOR := Color(0.75, 0.35, 1.0)
const SHIELD_ICON_COLOR := Color(0.78, 0.8, 0.86)
const HARNESS_COLOR := Color(1.0, 0.25, 0.2)
const HEAL_WRACK_COLOR := Color(0.35, 1.0, 0.45)
const SHIELD_WRACK_COLOR := Color(0.85, 0.88, 0.95)
const CONTROL_WRACK_COLOR := Color(0.7, 0.3, 1.0)

const SHADERS := {
	# The sprite's shape in one flat colour.
	"silhouette": """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
""",
	# A line just outside the sprite's shape. The copy's region is grown a few pixels so
	# the line has room past the texture's edge.
	"outline": """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform float width = 2.0;
float alpha_at(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { return 0.0; }
	return texture(tex, uv).a;
}
void fragment() {
	vec2 step_size = TEXTURE_PIXEL_SIZE * width;
	float near = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		near = max(near, alpha_at(TEXTURE, UV + vec2(cos(angle), sin(angle)) * step_size));
	}
	COLOR = vec4(tint.rgb, clamp(near - alpha_at(TEXTURE, UV), 0.0, 1.0) * tint.a);
}
""",
	# GATE.W(A)'s summons: an outline broken into drifting scanlines that flickers a little,
	# like a hologram.
	"digital_outline": """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform float width = 1.5;
float alpha_at(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) { return 0.0; }
	return texture(tex, uv).a;
}
void fragment() {
	vec2 step_size = TEXTURE_PIXEL_SIZE * width;
	float near = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		near = max(near, alpha_at(TEXTURE, UV + vec2(cos(angle), sin(angle)) * step_size));
	}
	float edge = clamp(near - alpha_at(TEXTURE, UV), 0.0, 1.0);
	float lines = 0.55 + 0.45 * step(0.5, fract(UV.y * 28.0 - TIME * 2.5));
	float flicker = 0.85 + 0.15 * sin(TIME * 23.0) * sin(TIME * 7.0);
	COLOR = vec4(tint.rgb, edge * lines * flicker * tint.a);
}
""",
	# A see-through brick wall in the sprite's shape.
	"bricks": """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.85, 0.87, 0.92, 0.5);
uniform vec2 bricks = vec2(4.0, 7.0);
void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec2 g = UV * bricks;
	if (mod(floor(g.y), 2.0) > 0.5) { g.x += 0.5; }
	vec2 f = fract(g);
	float brick = step(0.08, f.x) * step(f.x, 0.92) * step(0.12, f.y) * step(f.y, 0.88);
	vec3 col = mix(tint.rgb * 0.45, tint.rgb, brick);
	COLOR = vec4(col, a * tint.a);
}
""",
}

static var _shaders := {}
static var _glow_texture: Texture2D


static func enabled() -> bool:
	return DisplayServer.get_name() != "headless"


# ---------- Shared pieces ----------

static func _shader(key: String) -> Shader:
	if not _shaders.has(key):
		var shader := Shader.new()
		shader.code = SHADERS[key]
		_shaders[key] = shader
	return _shaders[key]


## A copy of the unit's sprite drawn with one of the shaders above. It's a child of the
## sprite, so it follows its position, size and stun tint. Made once, then reused.
static func _sprite_copy(unit: BattleUnit, key: String, shader_key: String, margin: int = 0) -> Sprite2D:
	var node := unit.sprite.get_node_or_null(key) as Sprite2D
	if node == null:
		node = Sprite2D.new()
		node.name = key
		node.texture = unit.sprite.texture
		node.offset = unit.sprite.offset
		node.flip_h = unit.sprite.flip_h
		if margin > 0 and node.texture != null:
			node.region_enabled = true
			node.region_rect = Rect2(Vector2(-margin, -margin), node.texture.get_size() + Vector2(margin, margin) * 2)
		var material := ShaderMaterial.new()
		material.shader = _shader(shader_key)
		node.material = material
		unit.sprite.add_child(node)
	return node


## The size the unit's sprite is drawn at, in pixels.
static func _sprite_size(unit: BattleUnit) -> Vector2:
	if unit.sprite == null or unit.sprite.texture == null:
		return Vector2(48, 48)
	return unit.sprite.texture.get_size() * unit.sprite.scale.abs()


## A soft round blob: white in the middle, see-through at the edge.
static func _glow() -> Texture2D:
	if _glow_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.45, Color(1, 1, 1, 0.55))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_glow_texture = texture
	return _glow_texture


## A glow behind the unit's sprite, made once and reused.
static func _glow_node(unit: BattleUnit, key: String) -> Sprite2D:
	var node := unit.get_node_or_null(key) as Sprite2D
	if node == null:
		node = Sprite2D.new()
		node.name = key
		node.texture = _glow()
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		node.material = material
		unit.add_child(node)
		unit.move_child(node, 0)   # first child: drawn behind the sprite
	return node


## Ground effects (auras, circles) sit in a layer just above the grid and below every
## unit, and follow their unit around.
static func _ground(unit: BattleUnit) -> Node2D:
	var parent := unit.grid.get_parent()
	var layer := parent.get_node_or_null("KeepsakeGround") as Node2D
	if layer == null:
		layer = Node2D.new()
		layer.name = "KeepsakeGround"
		unit.grid.add_sibling(layer)   # straight after the grid: drawn above it, below the units
	return layer


static func _ground_key(unit: BattleUnit, key: String) -> String:
	return "%s_%d" % [key, unit.get_instance_id()]


## Adds a one-off effect to the scene at `where`. It isn't a child of any unit, so it
## outlives a unit that dies.
static func _spawn(unit: BattleUnit, node: Node2D, where: Vector2) -> void:
	unit.get_tree().current_scene.add_child(node)
	node.global_position = where


## Removes a lasting effect (a glow, an aura) from the unit, e.g. when its status ends.
static func clear(unit: BattleUnit, key: String) -> void:
	if not is_instance_valid(unit):
		return
	for node in [unit.get_node_or_null(key), unit.sprite.get_node_or_null(key) if unit.sprite != null else null]:
		if node != null:
			node.queue_free()
	if unit.grid != null:
		var ground := unit.grid.get_parent().get_node_or_null("KeepsakeGround")
		if ground != null:
			var node := ground.get_node_or_null(_ground_key(unit, key))
			if node != null:
				node.queue_free()


# ---------- Swings ----------

## A sword sweeping across `aim` (radians), drawn on `parent`.
static func swing(parent: Node2D, aim: float, color: Color, width: float = 5.0) -> void:
	var sword := Line2D.new()
	sword.points = PackedVector2Array([Vector2(12, 0), Vector2(36, 0)])   # a bar pointing along +x
	sword.width = width
	sword.default_color = color
	sword.z_index = 10
	parent.add_child(sword)
	var local_aim := aim - parent.global_rotation   # `aim` is on screen; the parent may be turned
	sword.rotation = local_aim - BattleUnit.SWING_ARC
	var tween := sword.create_tween()
	tween.tween_property(sword, "rotation", local_aim + BattleUnit.SWING_ARC, BattleUnit.SWING_TIME)
	tween.tween_callback(sword.queue_free)


## Ghost Strike: a see-through copy of the unit appears just behind it, lunges at the
## target and swings (melee units), then fades.
static func ghost_strike(unit: BattleUnit, target: BattleUnit) -> void:
	if not enabled() or unit.sprite == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - unit.global_position
	var aim := to_target.angle()
	var dir := to_target.normalized() if to_target.length() > 0.1 else Vector2.RIGHT
	var ghost := Node2D.new()
	var body := Sprite2D.new()
	body.texture = unit.sprite.texture
	body.scale = unit.sprite.scale
	body.offset = unit.sprite.offset
	body.flip_h = unit.sprite.flip_h
	var material := ShaderMaterial.new()
	material.shader = _shader("silhouette")
	material.set_shader_parameter("tint", GHOST_TINT)
	body.material = material
	ghost.add_child(body)
	ghost.z_index = 5
	_spawn(unit, ghost, unit.global_position - dir * GHOST_OFFSET + dir.orthogonal() * 6.0)
	ghost.rotation = unit.global_rotation   # upright when the battle is watched turned around
	ghost.modulate.a = 0.0
	var start := ghost.position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 1.0, GHOST_DELAY)
	tween.tween_property(ghost, "position", start + dir * 10.0, 0.06)
	if unit.attack_range <= 1:
		tween.tween_callback(func(): swing(ghost, aim, Color(GHOST_TINT, 0.8)))
	tween.tween_interval(BattleUnit.SWING_TIME)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tween.tween_callback(ghost.queue_free)


# ---------- Glows and tints on the unit ----------

## A coloured glow behind the unit whose strength (0 to 1) can grow, e.g. per kill.
static func set_glow(unit: BattleUnit, key: String, color: Color, strength: float) -> void:
	if not enabled():
		return
	strength = clampf(strength, 0.0, 1.0)
	var node := _glow_node(unit, key)
	node.modulate = Color(color, 0.35 + 0.65 * strength)
	var diameter := _sprite_size(unit).length() * (0.9 + 0.5 * strength)
	node.scale = Vector2.ONE * diameter / 64.0


## Strength for a glow that grows with each stack and levels off: 35%, 58%, 73%, ...
static func stack_strength(stacks: int) -> float:
	return 1.0 - pow(0.65, stacks)


## Last Chance: a pulsing red glow for `duration` seconds.
static func pulse_glow(unit: BattleUnit, key: String, color: Color, duration: float) -> void:
	if not enabled():
		return
	var node := _glow_node(unit, key)
	node.modulate = Color(color, 0.6)
	node.scale = Vector2.ONE * _sprite_size(unit).length() * 1.5 / 64.0
	node.self_modulate = Color.WHITE
	var pulse := node.create_tween().set_loops()
	pulse.tween_property(node, "modulate:a", 1.0, 0.35)
	pulse.tween_property(node, "modulate:a", 0.45, 0.35)
	var life := node.create_tween()
	life.tween_interval(maxf(duration - 0.3, 0.0))
	life.tween_property(node, "self_modulate:a", 0.0, 0.3)
	life.tween_callback(node.queue_free)


## Phase Button: the unit turns blue (and a little see-through) for `duration` seconds.
static func phase_tint(unit: BattleUnit, duration: float) -> void:
	if not enabled() or unit.sprite == null:
		return
	unit.sprite.self_modulate = PHASE_TINT
	var tween := unit.sprite.create_tween()
	tween.tween_interval(duration)
	tween.tween_property(unit.sprite, "self_modulate", Color.WHITE, 0.15)


## GATE.W(A)'s summons and revived allies: a faint yellow hologram outline and glow that
## get brighter (and the outline thicker) with each of its boosts. 0 boosts = just summoned.
static func gate_glow(unit: BattleUnit, boosts: int, color: Color) -> void:
	if not enabled() or not is_instance_valid(unit) or unit.sprite == null:
		return
	var strength := 0.25 + 0.75 * stack_strength(boosts)   # 25%, then 51%, 68%, 80%, ...
	var outline := _sprite_copy(unit, "VfxGateGlow", "digital_outline", 4)
	var material := outline.material as ShaderMaterial
	material.set_shader_parameter("tint", Color(color, 0.35 + 0.65 * strength))
	material.set_shader_parameter("width", 1.0 + 1.5 * strength)
	set_glow(unit, "VfxGateAura", color, strength * 0.5)
	var aura := unit.get_node_or_null("VfxGateAura") as Sprite2D
	if aura != null:
		aura.modulate.a *= 0.35 + 0.65 * strength   # starts faint


## Manadrinker and Quickscar: a quick green outline when the item heals.
static func heal_flash(unit: BattleUnit) -> void:
	if not enabled() or unit.sprite == null:
		return
	var node := _sprite_copy(unit, "VfxHealOutline", "outline", 3)
	(node.material as ShaderMaterial).set_shader_parameter("tint", HEAL_OUTLINE)
	var old = node.get_meta("tween") if node.has_meta("tween") else null
	if old is Tween and old.is_valid():
		old.kill()
	node.modulate.a = 1.0
	var tween := node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, 0.3)
	node.set_meta("tween", tween)


## Momentum and Stubborn: shown while their health condition holds.
static func set_threshold_visual(unit: BattleUnit, visual: int, on: bool) -> void:
	if not enabled() or unit.sprite == null:
		return
	match visual:
		HealthThresholdStatEffect.Visual.WIND:
			var wind := unit.get_node_or_null("VfxWind") as WindSwirl
			if wind == null and on:
				wind = WindSwirl.new()
				wind.name = "VfxWind"
				wind.radius = _sprite_size(unit).length() * 0.45
				unit.add_child(wind)
			if wind != null:
				wind.visible = on
		HealthThresholdStatEffect.Visual.BRICKS:
			if on or unit.sprite.has_node("VfxBricks"):
				_sprite_copy(unit, "VfxBricks", "bricks").visible = on


# ---------- Ground effects ----------

## Spellward: a red, wobbling circle under the unit's feet for `duration` seconds.
static func ward_circle(unit: BattleUnit, duration: float) -> void:
	if not enabled():
		return
	var ground := _ground(unit)
	var key := _ground_key(unit, "VfxWardCircle")
	var circle := ground.get_node_or_null(key) as WardCircle
	if circle == null:
		circle = WardCircle.new()
		circle.name = key
		circle.unit = unit
		var size := _sprite_size(unit)
		circle.radius = size.x * 0.5
		circle.feet = size.y * 0.4
		ground.add_child(circle)
	circle.life = duration   # playing it again restarts the clock


## Blizzard: a slowly turning ring of snowflakes at the aura's edge.
static func snow_ring(unit: BattleUnit, radius_cells: int) -> void:
	_range_aura(unit, "VfxSnow", radius_cells, true, SNOW_COLOR)


## Dim Defense: a see-through teal circle showing the aura's reach.
static func dim_aura(unit: BattleUnit, radius_cells: int) -> void:
	_range_aura(unit, "VfxDim", radius_cells, false, DIM_COLOR)


## Lunck's Rally: a faint orange circle showing how far his aura reaches.
## Blue instead of orange when it also gives Insight (his A2 upgrade).
static func rally_aura(unit: BattleUnit, radius_cells: int, gives_insight: bool = false) -> void:
	_range_aura(unit, "VfxRally", radius_cells, false, RALLY_INSIGHT_COLOR if gives_insight else RALLY_COLOR, RALLY_STRENGTH)


## BATR.EE's Power Grid: a crackling purple ring at the passive's reach. Made once per
## unit; call clear(unit, "VfxGrid") first to redraw it at a new size.
static func grid_aura(unit: BattleUnit, radius_cells: int, color: Color) -> void:
	if not enabled():
		return
	var ground := _ground(unit)
	var name := _ground_key(unit, "VfxGrid")
	if ground.has_node(name):
		return
	var aura := StaticAura.new()
	aura.name = name
	aura.unit = unit
	aura.color = color
	aura.radius = (radius_cells + 0.5) * unit.grid.hex_size * BattleGrid.SQRT3
	ground.add_child(aura)


## Merribold's Bellow: a spiky red ring that bursts out to the Bellow's reach.
static func bellow_ring(unit: BattleUnit, radius_cells: int) -> void:
	if not enabled() or unit.grid == null:
		return
	var ring := SpikyRing.new()
	ring.color = BELLOW_RING_COLOR
	ring.max_radius = (radius_cells + 0.5) * unit.grid.hex_size * BattleGrid.SQRT3
	ring.z_index = 6
	_spawn(unit, ring, unit.global_position)


# ---------- Unit gambit visuals ----------

## Lunck's Rally shield: an orange flag over the head. Lunck's Adoration: an orange heart.
## Stays `duration` seconds; playing it again restarts the clock.
static func head_icon(unit: BattleUnit, key: String, kind: int, color: Color, duration: float) -> void:
	if not enabled() or not is_instance_valid(unit):
		return
	var icon := unit.get_node_or_null(key) as HeadIcon
	if icon == null:
		icon = HeadIcon.new()
		icon.name = key
		icon.kind = kind
		icon.color = color
		icon.position = Vector2(0.0, HEAD_ICON_HEIGHT)
		icon.z_index = 12
		unit.add_child(icon)
	icon.life = duration


## Prancelot's Crescendo: pink notes floating around him until clear(unit, "VfxCrescendo").
static func note_swirl(unit: BattleUnit) -> void:
	if not enabled() or not is_instance_valid(unit) or _still_there(unit, "VfxCrescendo"):
		return
	var swirl := NoteSwirl.new()
	swirl.name = "VfxCrescendo"
	swirl.color = CRESCENDO_COLOR
	swirl.radius = _sprite_size(unit).x * 0.55
	swirl.z_index = 11
	unit.add_child(swirl)


## Bremes' Sunder Strike: a quick teal double slash across the enemy.
static func teal_slash(target: BattleUnit) -> void:
	if not enabled() or not is_instance_valid(target):
		return
	var slash := Slash.new()
	slash.color = BREMES_TEAL
	slash.size = _sprite_size(target).y * 0.6
	slash.z_index = 13
	_spawn(target, slash, target.global_position)
	slash.rotation = target.global_rotation


## Scour's Haywire: a fiery spiked blast out to the explosion's reach.
static func haywire_blast(unit: BattleUnit, radius_cells: int) -> void:
	if not enabled() or unit.grid == null:
		return
	var ring := SpikyRing.new()
	ring.color = Color(1.0, 0.55, 0.15)
	ring.max_radius = (radius_cells + 0.5) * unit.grid.hex_size * BattleGrid.SQRT3
	ring.z_index = 14
	_spawn(unit, ring, unit.global_position)
	burst(unit, Color(1.0, 0.75, 0.3))


## Recycloid's passive: a green orb of recycled health floating from where a unit died to
## the ally it heals.
static func recycle_orb(from: Vector2, to_unit: BattleUnit) -> void:
	if not enabled() or not is_instance_valid(to_unit):
		return
	var orb := Burst.new()
	orb.color = VacuumChannel.VACUUM_COLOR
	to_unit.get_tree().current_scene.add_child(orb)
	orb.global_position = from
	var tween := orb.create_tween()
	tween.tween_property(orb, "global_position", to_unit.global_position, 0.35)
	heal_flash(to_unit)


## Mono-Virus: a purple orb carrying a dead unit's stacks to the ally that inherits them.
static func virus_jump(from: Vector2, to_unit: BattleUnit) -> void:
	if not enabled() or not is_instance_valid(to_unit):
		return
	var orb := Burst.new()
	orb.color = MonoVirusStatus.SETTINGS.color
	to_unit.get_tree().current_scene.add_child(orb)
	orb.global_position = from
	orb.create_tween().tween_property(orb, "global_position", to_unit.global_position, 0.35)


## Grouser's claw: two neon yellow blades closing on the target like a pincer.
static func claw_snip(target: BattleUnit) -> void:
	if not enabled() or not is_instance_valid(target):
		return
	var claw := Pincer.new()
	claw.color = WardShiftStatus.COLOR
	claw.size = _sprite_size(target).y * 1.0
	claw.z_index = 13
	_spawn(target, claw, target.global_position)
	claw.rotation = target.global_rotation


## VE5TIBULE's gift: the item's icon flies from him to the ally, then pops.
static func gift_icon(from: Vector2, to_unit: BattleUnit, item: Keepsake) -> void:
	if not enabled() or not is_instance_valid(to_unit) or item == null:
		return
	var icon := Sprite2D.new()
	icon.texture = item.get_icon(20)
	icon.scale = Vector2.ONE * 18.0 / maxf(icon.texture.get_height(), 1.0)   # about 18 pixels tall
	icon.z_index = 15
	to_unit.get_tree().current_scene.add_child(icon)
	icon.global_position = from
	var tween := icon.create_tween()
	tween.tween_property(icon, "global_position", to_unit.global_position + Vector2(0, -20), 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", icon.scale * 1.6, 0.15)
	tween.parallel().tween_property(icon, "modulate:a", 0.0, 0.15)
	tween.tween_callback(icon.queue_free)


## Mono-Virus: a small purple badge at the unit's lower right showing how many stacks it
## carries. Call again whenever the count changes; clear it with clear(unit, key).
static func virus_badge(unit: BattleUnit, key: String, stacks: int) -> void:
	if not enabled() or not is_instance_valid(unit):
		return
	var badge := unit.get_node_or_null(key) as StackBadge
	if badge == null or badge.is_queued_for_deletion():
		badge = StackBadge.new()
		badge.name = key
		badge.z_index = 13
		var size := _sprite_size(unit)
		badge.position = Vector2(size.x * 0.5 - 2.0, size.y * 0.5 - 6.0)
		unit.add_child(badge)
	badge.color = MonoVirusStatus.SETTINGS.color
	if badge.count != stacks:
		badge.count = stacks
		badge.pop = 0.0   # a little bounce each time it changes
	badge.queue_redraw()


## BAR.RAJ's missiles: a round explosion, bright in the middle and fading outwards, that
## grows to the size of the blast.
static func missile_blast(parent: Node, at: Vector2, radius: float, color: Color) -> void:
	if not enabled() or parent == null:
		return
	var blast := RadialBlast.new()
	blast.color = color
	blast.max_radius = radius
	blast.z_index = 14
	parent.add_child(blast)
	blast.global_position = at


## Lordred's Cleave: one large pinkish red slash cutting right through the target.
static func cleave_slash(target: BattleUnit) -> void:
	if not enabled() or not is_instance_valid(target):
		return
	var slash := Slash.new()
	slash.color = LORDRED_RED
	slash.size = _sprite_size(target).y * 1.5
	slash.count = 1
	slash.thickness = 2.2
	slash.z_index = 13
	_spawn(target, slash, target.global_position)
	slash.rotation = target.global_rotation


## Lordred's Taunt: a slowly turning spiked pinkish red ring around him for `duration`
## seconds. Playing it again restarts the clock.
static func taunt_ring(unit: BattleUnit, duration: float) -> void:
	if not enabled() or not is_instance_valid(unit):
		return
	var ring := unit.get_node_or_null("VfxTaunt") as SpikedAura
	if ring == null or ring.is_queued_for_deletion():
		ring = SpikedAura.new()
		ring.name = "VfxTaunt"
		ring.color = LORDRED_RED
		ring.radius = _sprite_size(unit).x * 0.75
		ring.z_index = -1   # behind the unit's sprite
		unit.add_child(ring)
	ring.life = duration
	ring.time = 0.0


## Bremes' Mirror Image: a teal puff of smoke at the unit's feet.
static func smoke_puff(unit: BattleUnit) -> void:
	if not enabled() or not is_instance_valid(unit):
		return
	var puff := SmokePuff.new()
	puff.color = BREMES_TEAL
	var size := _sprite_size(unit)
	puff.spread = size.x * 0.55
	puff.feet = size.y * 0.35
	puff.z_index = 13
	_spawn(unit, puff, unit.global_position)
	puff.rotation = unit.global_rotation


## Geomond's Tectonic Stance: slowly flowing magma on the ground under him until
## clear(unit, "VfxMagma").
static func magma_pool(unit: BattleUnit) -> void:
	if not enabled() or not is_instance_valid(unit) or unit.grid == null:
		return
	var ground := _ground(unit)
	var key := _ground_key(unit, "VfxMagma")
	if _still_there(ground, key):
		return
	var pool := MagmaPool.new()
	pool.name = key
	pool.unit = unit
	pool.radius = unit.grid.hex_size * 0.95
	pool.feet = _sprite_size(unit).y * 0.3
	ground.add_child(pool)


static func _range_aura(unit: BattleUnit, key: String, radius_cells: int, snow: bool, color: Color, strength: float = 1.0) -> void:
	if not enabled():
		return
	var ground := _ground(unit)
	var name := _ground_key(unit, key)
	if ground.has_node(name):
		return
	var aura := RangeAura.new()
	aura.name = name
	aura.unit = unit
	aura.snow = snow
	aura.color = color
	aura.strength = strength
	aura.radius = (radius_cells + 0.5) * unit.grid.hex_size * BattleGrid.SQRT3
	ground.add_child(aura)


# ---------- One-off pops ----------

## Burst Rod: a blue explosion on the enemy.
static func burst(target: BattleUnit, color: Color = BURST_COLOR) -> void:
	if not enabled():
		return
	var node := Burst.new()
	node.color = color
	node.z_index = 15
	_spawn(target, node, target.global_position)


## Opportunist: purple sparks flying off a wracked target.
static func sparks(target: BattleUnit, color: Color = SPARK_COLOR) -> void:
	if not enabled():
		return
	var node := Sparks.new()
	node.color = color
	node.z_index = 15
	_spawn(target, node, target.global_position)


## Saviour and Haunting Idol: a swirl of energy where an effect wracked.
static func flourish(at: Node2D, color: Color) -> void:
	if not enabled() or not is_instance_valid(at) or not at.is_inside_tree():
		return
	var node := Flourish.new()
	node.color = color
	node.z_index = 15
	at.get_tree().current_scene.add_child(node)
	node.global_position = at.global_position


## Shredder: a shield cracking in two over the enemy. At most a few times a second per
## enemy, so fast attackers don't bury it in shields.
static func shred(target: BattleUnit) -> void:
	if not enabled() or _throttled(target, "vfx_shred", 400):
		return
	var node := BrokenShield.new()
	node.z_index = 15
	_spawn(target, node, target.global_position + Vector2(0, -6))


## Finisher's skull and Frailty Frame's arm: a small icon that pops up over the unit.
static func pop_icon(unit: BattleUnit, icon: String, throttle_key: String = "") -> void:
	if not enabled() or (throttle_key != "" and _throttled(unit, throttle_key, 300)):
		return
	var label := Label.new()
	label.text = icon
	label.size = Vector2(30, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 20
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	unit.get_tree().current_scene.add_child(label)
	# Off to the right of the damage numbers, level with the item icons (placed by its
	# centre, and turned with the view so it stays upright).
	label.pivot_offset = label.size / 2.0
	label.rotation = unit.global_rotation
	label.global_position = unit.global_position + Vector2(29, -52).rotated(unit.global_rotation) - label.size / 2.0
	label.scale = Vector2(0.4, 0.4)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.1)
	tween.tween_interval(0.35)
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0.0, -10.0).rotated(unit.global_rotation), 0.3)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(label.queue_free)


## Halting Harness: a red down arrow beside the slowed enemy, with how many stacks it has.
static func harness_mark(target: BattleUnit, duration: float) -> void:
	if not enabled() or not is_instance_valid(target):
		return
	var mark := target.get_node_or_null("VfxHarness") as HarnessMark
	if mark == null:
		mark = HarnessMark.new()
		mark.name = "VfxHarness"
		mark.position = Vector2(_sprite_size(target).x * 0.5 + 4.0, -8.0)
		mark.z_index = 12
		target.add_child(mark)
	mark.add(duration)


## True if `parent` has a child named `key` that isn't on its way out. One that was just
## cleared (a recast removes the old status first) is taken out of the way instead.
static func _still_there(parent: Node, key: String) -> bool:
	var old := parent.get_node_or_null(key)
	if old == null:
		return false
	if old.is_queued_for_deletion():
		parent.remove_child(old)
		return false
	return true


## True if this effect played on `unit` less than `ms` milliseconds ago.
static func _throttled(unit: Node, key: String, ms: int) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(unit.get_meta(key, -100000)) < ms:
		return true
	unit.set_meta(key, now)
	return false


# ---------- The effect nodes ----------

## Something drawn on the ground that follows a unit, optionally for a limited time.
class Follower extends Node2D:
	var unit: BattleUnit
	var life := -1.0   # seconds left; below 0 = until removed
	var time := 0.0

	func _process(delta: float) -> void:
		if not is_instance_valid(unit) or not unit.alive:
			queue_free()
			return
		global_position = unit.global_position
		global_rotation = unit.global_rotation   # keeps "below the unit" below it on screen
		time += delta
		if life >= 0.0:
			life -= delta
			if life <= 0.0:
				queue_free()
				return
		queue_redraw()


class WardCircle extends Follower:
	var radius := 20.0
	var feet := 18.0   # pixels below the unit's centre

	func _draw() -> void:
		var fade := clampf(life / 0.3, 0.0, 1.0) if life >= 0.0 else 1.0
		var points := PackedVector2Array()
		for i in 49:
			var angle := TAU * i / 48.0
			var wobble := 1.0 + 0.09 * sin(angle * 6.0 + time * 9.0) + 0.05 * sin(angle * 3.0 - time * 6.0)
			points.append(Vector2(cos(angle) * radius * wobble, feet + sin(angle) * radius * 0.4 * wobble))
		draw_colored_polygon(points, Color(KeepsakeVfx.WARD_CIRCLE_COLOR, 0.18 * fade))
		draw_polyline(points, Color(KeepsakeVfx.WARD_CIRCLE_COLOR, 0.9 * fade), 2.0, true)


class RangeAura extends Follower:
	var radius := 100.0
	var snow := false
	var color := Color.WHITE
	var strength := 1.0   # scales how see-through it is (plain auras only)

	func _draw() -> void:
		if not snow:
			draw_circle(Vector2.ZERO, radius, Color(color, 0.09 * strength))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, 0.4 * strength), 1.5, true)
			return
		draw_circle(Vector2.ZERO, radius, Color(color, 0.04))
		var flakes := 18
		for i in flakes:
			var angle := TAU * i / flakes + time * 0.25   # a full turn every 25 seconds
			_flake(Vector2(cos(angle), sin(angle)) * radius, 4.5, -time * 0.8 + i)
		for i in flakes:   # a fainter inner ring turning the other way
			var angle := TAU * (i + 0.5) / flakes - time * 0.18
			_flake(Vector2(cos(angle), sin(angle)) * radius * 0.88, 3.0, time * 0.6 + i, 0.3)

	func _flake(center: Vector2, size: float, spin: float, alpha: float = 0.6) -> void:
		for arm in 3:
			var dir := Vector2.from_angle(spin + arm * PI / 3.0) * size
			draw_line(center - dir, center + dir, Color(color, alpha), 1.2, true)


## BATR.EE's Power Grid: a faint purple disc whose edge is a crackling ring of little
## lightning arcs that jump to new shapes several times a second, with a few sparks.
class StaticAura extends Follower:
	const ARCS := 14          # pieces the edge is broken into
	const JUMPS := 12.0       # times a second the arcs change shape
	var radius := 100.0
	var color := Color.WHITE

	## A repeatable "random" number from 0 to 1 for this arc and moment (looks only, so it
	## never touches the battle's random numbers).
	func _noise(a: float, b: float) -> float:
		return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(color, 0.06))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, 0.18), 1.0, true)
		var tick := floorf(time * JUMPS)
		for arc in ARCS:
			if _noise(arc, tick) < 0.3:
				continue   # some gaps, so the ring flickers
			var start := TAU * arc / ARCS
			var points := PackedVector2Array()
			for i in 5:
				var angle := start + TAU / ARCS * i / 4.0
				var jitter := (_noise(arc * 7.0 + i, tick) - 0.5) * 7.0
				points.append(Vector2.from_angle(angle) * (radius + jitter))
			var bright := 0.35 + 0.45 * _noise(arc + 3.0, tick)
			draw_polyline(points, Color(color, bright), 1.5, true)
		for spark in 4:   # little sparks hopping round the edge
			var angle := TAU * _noise(spark + 11.0, tick)
			var at := Vector2.from_angle(angle) * radius
			draw_circle(at, 1.8, Color(color.lightened(0.5), 0.8))


class WindSwirl extends Node2D:
	var radius := 24.0
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		for streak in 3:
			var start := time * (2.6 + streak * 0.5) + streak * TAU / 3.0
			var r := radius * (0.85 + 0.12 * streak)
			var points := PackedVector2Array()
			var colors := PackedColorArray()
			for i in 10:
				var t := i / 9.0
				var angle := start + t * 1.1   # each streak covers about 60 degrees
				points.append(Vector2(cos(angle) * r, sin(angle) * r * 0.55 + 6.0))
				colors.append(Color(KeepsakeVfx.WIND_COLOR, KeepsakeVfx.WIND_COLOR.a * t))   # fades toward its tail
			draw_polyline_colors(points, colors, 1.5, true)


## A small icon over a unit's head that pops in, then fades out at the end of its life.
class HeadIcon extends Node2D:
	enum { FLAG, HEART }
	var kind: int = FLAG   # FLAG or HEART
	var color := Color.WHITE
	var life := 1.0
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		scale = Vector2.ONE * minf(time / 0.12, 1.0)      # pops in
		modulate.a = clampf(life / 0.3, 0.0, 1.0)          # fades out
		queue_redraw()

	func _draw() -> void:
		var outline := Color(0.15, 0.08, 0.02, 0.9)
		if kind == FLAG:
			var wave := sin(time * 6.0) * 1.2
			draw_line(Vector2(-5, 7), Vector2(-5, -8), outline, 2.0, true)   # the pole
			var cloth := PackedVector2Array([Vector2(-4, -8), Vector2(7, -5 + wave), Vector2(-4, -1)])
			draw_colored_polygon(cloth, color)
			cloth.append(cloth[0])
			draw_polyline(cloth, outline, 1.0, true)
		else:
			var points := PackedVector2Array()
			for i in 32:
				var t := TAU * i / 32.0
				# The classic heart curve, scaled to about 14 pixels across.
				points.append(Vector2(16.0 * pow(sin(t), 3.0),
						-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * 0.42)
			draw_colored_polygon(points, color)
			points.append(points[0])
			draw_polyline(points, outline, 1.0, true)


## Music notes drifting round and round a unit, bobbing up and down.
class NoteSwirl extends Node2D:
	const NOTES := ["♪", "♫", "♪", "♫"]
	var color := Color.WHITE
	var radius := 24.0
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for i in NOTES.size():
			var angle := time * 1.3 + TAU * i / NOTES.size()
			var pos := Vector2(cos(angle) * radius, -16.0 + sin(angle) * radius * 0.45 + sin(time * 3.0 + i) * 4.0)
			var alpha := 0.6 + 0.4 * sin(time * 2.0 + i * 1.7)
			draw_string_outline(font, pos + Vector2(-5, 6), NOTES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 3, Color(0.25, 0.05, 0.15, alpha))
			draw_string(font, pos + Vector2(-5, 6), NOTES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(color, alpha))


## A spiked ring around a unit that grows in, turns slowly, and fades at the end.
class SpikedAura extends Node2D:
	const SPIKES := 16
	var color := Color.WHITE
	var radius := 30.0
	var life := 1.0
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var grow := minf(time / 0.15, 1.0)
		var fade := clampf(life / 0.3, 0.0, 1.0)
		var r := radius * (0.6 + 0.4 * grow)
		var pulse := 1.0 + 0.04 * sin(time * 6.0)
		var points := PackedVector2Array()
		for i in SPIKES * 2 + 1:
			var angle := TAU * i / (SPIKES * 2) + time * 0.6
			var reach := r * pulse * (1.25 if i % 2 == 0 else 1.0)
			points.append(Vector2.from_angle(angle) * Vector2(reach, reach * 0.75))   # flattened onto the ground
		draw_colored_polygon(points.slice(0, points.size() - 1), Color(color, 0.12 * fade))
		draw_polyline(points, Color(color, 0.85 * fade), 2.0, true)


## Quick slash marks that sweep across the target and fade: two crossing ones by default,
## or a single big one (count 1, thicker).
class Slash extends Node2D:
	const TIME := 0.28
	var color := Color.WHITE
	var size := 30.0
	var count := 2
	var thickness := 1.0
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		if time >= TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for i in count:
			# The second slash starts a little after the first, crossing it.
			var t := clampf((time - i * 0.06) / (TIME * 0.6), 0.0, 1.0)
			if t <= 0.0:
				continue
			var fade := clampf(1.0 - (time - i * 0.06 - TIME * 0.4) / (TIME * 0.6), 0.0, 1.0)
			var from := Vector2(-size, -size) * 0.5 if i == 0 else Vector2(size, -size) * 0.5
			var to := -from
			var tip := from.lerp(to, t)
			var tail := from.lerp(to, maxf(t - 0.55, 0.0))
			draw_line(tail, tip, Color(color, 0.35 * fade), 7.0 * thickness, true)
			draw_line(tail, tip, Color(color, fade), 3.0 * thickness, true)
			draw_line(tail, tip, Color(1, 1, 1, 0.8 * fade), 1.0 * thickness, true)


## A puff of smoke balls bursting out at a unit's feet and drifting up as they fade.
class SmokePuff extends Node2D:
	const TIME := 0.55
	const BALLS := 9
	var color := Color.WHITE
	var spread := 24.0
	var feet := 18.0
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		if time >= TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := time / TIME
		var out := 1.0 - pow(1.0 - t, 3.0)   # bursts out fast, then slows
		var fade := 1.0 - t
		draw_circle(Vector2(0, feet), spread * (0.3 + 0.7 * out), Color(1, 1, 1, 0.35 * fade * fade))
		for i in BALLS:
			var dir := Vector2.from_angle(TAU * i / BALLS + 0.4)
			var pos := Vector2(dir.x * spread * out, feet + dir.y * spread * 0.45 * out - 10.0 * t)
			var r := spread * (0.22 + 0.25 * out) * (0.8 + 0.2 * sin(i * 2.3))
			draw_circle(pos, r, Color(color.darkened(0.15 * (i % 3)), 0.55 * fade))


## Slowly churning magma on the ground under a unit: a dark red pool with glowing
## orange and yellow patches drifting around in it.
class MagmaPool extends Follower:
	const BLOBS := 7
	var radius := 30.0
	var feet := 14.0
	var fade_in := 0.0

	func _draw() -> void:
		fade_in = minf(fade_in + get_process_delta_time() / 0.4, 1.0)
		var a := fade_in
		var centre := Vector2(0, feet)
		for ring in 4:   # soft edge: a few rings getting fainter outward
			var r := radius * (1.0 - ring * 0.12)
			draw_circle(centre, r, Color(0.35, 0.05, 0.02, (0.18 + ring * 0.1) * a))
		for i in BLOBS:
			var speed := 0.25 + 0.07 * i
			var angle := time * speed * (1.0 if i % 2 == 0 else -1.0) + i * 1.9
			var reach := radius * (0.25 + 0.4 * (0.5 + 0.5 * sin(time * 0.4 + i)))
			var pos := centre + Vector2(cos(angle), sin(angle)) * reach
			var glow := 0.5 + 0.5 * sin(time * 1.1 + i * 2.1)
			var size := radius * (0.18 + 0.08 * glow)
			draw_circle(pos, size, Color(1.0, 0.38 + 0.2 * glow, 0.05, (0.35 + 0.3 * glow) * a))
			draw_circle(pos, size * 0.45, Color(1.0, 0.85, 0.3, (0.25 + 0.35 * glow) * a))


## A star-edged ring that grows fast from the centre to `max_radius`, fading as it goes.
class SpikyRing extends Node2D:
	const TIME := 0.3
	const SPIKES := 28
	var color := Color.WHITE
	var max_radius := 100.0
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		if time >= TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := clampf(time / TIME, 0.0, 1.0)
		var radius := max_radius * (1.0 - pow(1.0 - t, 3.0))   # fast at first, easing out
		var fade := 1.0 - t * t
		if radius < 2.0:
			return   # too small to draw a polygon yet
		var points := PackedVector2Array()
		for i in SPIKES * 2:
			var reach := radius if i % 2 == 0 else radius * 0.8
			points.append(Vector2.from_angle(TAU * i / (SPIKES * 2)) * reach)
		draw_colored_polygon(points, Color(color, 0.18 * fade))
		points.append(points[0])
		draw_polyline(points, Color(color, 0.9 * fade), 2.0, true)


## Two curved blades that swing shut across a point, then fade.
class Pincer extends Node2D:
	const TIME := 0.25
	var color := Color.WHITE
	var size := 30.0
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		if time >= TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := clampf(time / (TIME * 0.5), 0.0, 1.0)         # closing
		var fade := clampf(1.0 - (time - TIME * 0.5) / (TIME * 0.5), 0.0, 1.0)
		var open := lerpf(0.9, 0.05, t * t)                    # half-angle between the blades
		for side: float in [-1.0, 1.0]:
			var points := PackedVector2Array()
			for i in 9:
				var a := -PI / 2.0 + side * open * (1.0 - i / 8.0)   # a curve that ends at the tip
				points.append(Vector2.from_angle(a + side * 0.6) * size * 0.5 + Vector2(side * size * 0.15, size * 0.25))
			draw_polyline(points, Color(0, 0, 0, 0.5 * fade), 9.0, true)   # dark edge, so it shows on a glow
			draw_polyline(points, Color(color, 0.5 * fade), 7.0, true)
			draw_polyline(points, Color(color, fade), 4.0, true)
		if t >= 1.0:
			draw_circle(Vector2(0, -size * 0.2), 4.0 * fade + 1.0, Color(1, 1, 1, 0.9 * fade))


class StackBadge extends Node2D:
	const POP_TIME := 0.15
	const FONT_SIZE := 11
	var color := Color.WHITE
	var count := 0
	var pop := POP_TIME   # time since the count last changed

	func _process(delta: float) -> void:
		if pop < POP_TIME:
			pop += delta
			scale = Vector2.ONE * (1.0 + 0.35 * (1.0 - minf(pop / POP_TIME, 1.0)))
			queue_redraw()

	func _draw() -> void:
		var text := str(count)
		var font := ThemeDB.fallback_font
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE)
		var radius := maxf(7.0, text_size.x / 2.0 + 3.0)
		draw_circle(Vector2.ZERO, radius + 1.5, Color(0.08, 0.02, 0.12, 0.95))   # dark rim
		draw_circle(Vector2.ZERO, radius, color.darkened(0.25))
		var at := Vector2(-text_size.x / 2.0, font.get_ascent(FONT_SIZE) / 2.0 - 1.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, Color(0.08, 0.02, 0.12))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)


class RadialBlast extends Node2D:
	const TIME := 0.3
	const RINGS := 6   # stacked circles, each fainter towards the edge
	var color := Color.WHITE
	var max_radius := 40.0
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		if time >= TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := clampf(time / TIME, 0.0, 1.0)
		var radius := max_radius * (1.0 - pow(1.0 - t, 3.0))   # fast at first, easing out
		var fade := 1.0 - t * t
		for i in RINGS:
			var share := 1.0 - float(i) / RINGS   # 1 = the outer circle
			draw_circle(Vector2.ZERO, maxf(radius * share, 1.0), Color(color, 0.16 * fade))
		draw_circle(Vector2.ZERO, maxf(radius * 0.3, 1.0), Color(1, 1, 1, 0.5 * fade))
		draw_arc(Vector2.ZERO, maxf(radius, 1.0), 0.0, TAU, 40, Color(color, 0.6 * fade), 1.5, true)


class Burst extends Node2D:
	const TIME := 0.35
	var color := Color.WHITE
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		if time >= TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := time / TIME
		var fade := 1.0 - t
		draw_circle(Vector2.ZERO, 6.0 + 18.0 * t, Color(color, 0.45 * fade))
		draw_circle(Vector2.ZERO, 4.0 + 6.0 * t, Color(1, 1, 1, 0.7 * fade))
		draw_arc(Vector2.ZERO, 8.0 + 24.0 * t, 0.0, TAU, 32, Color(color, fade), 2.0, true)
		for i in 8:
			var dir := Vector2.from_angle(TAU * i / 8.0 + 0.3)
			draw_line(dir * (10.0 + 14.0 * t), dir * (16.0 + 22.0 * t), Color(color, fade), 2.0, true)


class Sparks extends Node2D:
	const TIME := 0.4
	var color := Color.WHITE
	var time := 0.0
	var _velocities: Array[Vector2] = []

	func _ready() -> void:
		for i in 9:
			_velocities.append(Vector2.from_angle(randf() * TAU) * randf_range(60.0, 130.0) + Vector2(0, -40))

	func _process(delta: float) -> void:
		time += delta
		if time >= TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var fade := 1.0 - time / TIME
		for v in _velocities:
			var pos := v * time + Vector2(0, 160.0) * time * time   # a little gravity
			var tail := pos - (v + Vector2(0, 320.0) * time).normalized() * 5.0
			draw_line(tail, pos, Color(color, fade), 1.5, true)
			draw_circle(pos, 1.2, Color(1, 1, 1, fade))


class Flourish extends Node2D:
	const TIME := 0.5
	var color := Color.WHITE
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		if time >= TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := time / TIME
		var fade := 1.0 - t * t
		for arm in 4:
			var points := PackedVector2Array()
			var colors := PackedColorArray()
			for i in 12:
				var s := i / 11.0
				var angle := arm * TAU / 4.0 + t * 4.0 + s * 2.2
				var r := (4.0 + 22.0 * t) * (0.35 + 0.65 * s)
				points.append(Vector2.from_angle(angle) * r)
				colors.append(Color(color, fade * s))
			draw_polyline_colors(points, colors, 2.0, true)
		draw_circle(Vector2.ZERO, 3.0 * (1.0 - t), Color(1, 1, 1, fade))


class BrokenShield extends Node2D:
	const TIME := 0.45
	var time := 0.0

	func _process(delta: float) -> void:
		time += delta
		if time >= TIME:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := time / TIME
		var fade := 1.0 - t
		var apart := 1.0 + 5.0 * t
		# A shield: flat top, straight sides, pointed bottom, cracked down the middle.
		var left := PackedVector2Array([Vector2(0, -8), Vector2(-7, -8), Vector2(-7, 0), Vector2(0, 9),
				Vector2(1, 4), Vector2(-1, 0), Vector2(1, -4)])
		var right := PackedVector2Array([Vector2(0, -8), Vector2(7, -8), Vector2(7, 0), Vector2(0, 9),
				Vector2(1, 4), Vector2(-1, 0), Vector2(1, -4)])
		for half in [[left, -1.0], [right, 1.0]]:
			var shape: PackedVector2Array = half[0]
			var moved := PackedVector2Array()
			for p in shape:
				moved.append(p + Vector2(half[1] * apart, apart * 0.5))
			draw_colored_polygon(moved, Color(KeepsakeVfx.SHIELD_ICON_COLOR, fade))
			moved.append(moved[0])
			draw_polyline(moved, Color(0.1, 0.1, 0.12, fade), 1.0, true)


class HarnessMark extends Node2D:
	var _ends: Array[float] = []   # when each stack runs out
	var time := 0.0

	func add(duration: float) -> void:
		_ends.append(time + duration)
		queue_redraw()

	func _process(delta: float) -> void:
		time += delta
		var before := _ends.size()
		_ends = _ends.filter(func(e): return e > time)
		if _ends.is_empty():
			queue_free()
		elif _ends.size() != before:
			queue_redraw()

	func _draw() -> void:
		var arrow := PackedVector2Array([Vector2(-2, -6), Vector2(2, -6), Vector2(2, 0), Vector2(5, 0),
				Vector2(0, 6), Vector2(-5, 0), Vector2(-2, 0)])
		draw_colored_polygon(arrow, KeepsakeVfx.HARNESS_COLOR)
		arrow.append(arrow[0])
		draw_polyline(arrow, Color.BLACK, 1.0, true)
		var font := ThemeDB.fallback_font
		var text := "%dx" % _ends.size()
		draw_string_outline(font, Vector2(6, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color.BLACK)
		draw_string(font, Vector2(6, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, KeepsakeVfx.HARNESS_COLOR)
