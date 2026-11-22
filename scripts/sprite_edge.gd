class_name SpriteEdge
## Pixel-accurate unit bodies. Shots hit, and beams stop, at the first solid pixel of the
## target's sprite instead of at its centre.
##
## Each sprite texture gets a map of its solid pixels the first time it's needed, kept for
## the rest of the run. Sims read the same pixels (they load fine without a screen), so the
## computer's planning sims and the real game agree.
##
## Gameplay uses the sprite at rest: its normal position and size, ignoring lunges, jolts,
## pulses, FRAME's stretch and other animations (which don't run in sims), and ignoring the
## online view turn (so both players' games hit at the same moment). Beams can ask for the
## sprite as drawn instead (`visual`), since where their line ends is only a picture.

const ALPHA_THRESHOLD := 0.1   # pixels more see-through than this don't count as body
const MARCH_STEP := 2.0        # pixels between checks along a path

static var _masks := {}   # Texture2D -> BitMap (null when the texture has no readable pixels)


## The solid-pixel map for a texture, built once.
static func mask(texture: Texture2D) -> BitMap:
	if texture == null:
		return null
	if _masks.has(texture):
		return _masks[texture]
	var bitmap: BitMap = null
	var image := texture.get_image()
	if image != null and not image.is_empty():
		if image.is_compressed():
			image.decompress()
		bitmap = BitMap.new()
		bitmap.create_from_image_alpha(image, ALPHA_THRESHOLD)
	_masks[texture] = bitmap
	return bitmap


## True if `point` (on the board) is on a solid pixel of the unit's sprite.
## False when the unit has no sprite map to test (callers fall back to the centre).
static func contains(unit: BattleUnit, point: Vector2, visual: bool = false) -> bool:
	var sprite := unit.sprite
	if sprite == null:
		return false
	var bitmap := mask(sprite.texture)
	if bitmap == null:
		return false
	var local: Vector2
	if visual:
		local = sprite.to_local(point) - sprite.offset
	else:
		var body_scale := unit.rest_sprite_scale()
		if body_scale.x == 0.0 or body_scale.y == 0.0:
			return false
		local = (point - unit.global_position - unit.rest_sprite_position) / body_scale
		local -= unit.rest_sprite_offset   # at rest: a Knock-up's lift doesn't count
	var size := bitmap.get_size()
	if sprite.centered:
		local += Vector2(size) * 0.5
	var px := Vector2i(floori(local.x), floori(local.y))
	if px.x < 0 or px.y < 0 or px.x >= size.x or px.y >= size.y:
		return false
	return bitmap.get_bitv(px)


## How far out from the unit's centre its sprite can reach, so paths only need checking
## inside that circle.
static func reach(unit: BattleUnit) -> float:
	if unit.sprite == null or unit.sprite.texture == null:
		return 0.0
	var size := unit.sprite.texture.get_size() * unit.rest_sprite_scale().abs()
	return (size * 0.5).length() + (unit.sprite.offset * unit.rest_sprite_scale().abs()).length() \
		+ unit.rest_sprite_position.length()


## The first point on the path `from` → `to` that touches the unit's sprite, or null if the
## path never does. Only the part of the path near the unit is checked.
static func first_touch(unit: BattleUnit, from: Vector2, to: Vector2, visual: bool = false) -> Variant:
	var radius := reach(unit) * (1.6 if visual else 1.0)   # drawn sprites can be stretched
	if radius <= 0.0:
		return null
	var length := from.distance_to(to)
	if length <= 0.0:
		return from if contains(unit, from, visual) else null
	var dir := (to - from) / length
	# Skip ahead to where the path first comes within `radius` of the unit's centre.
	var along := clampf((unit.global_position - from).dot(dir), 0.0, length)
	var closest := from + dir * along
	var off := closest.distance_to(unit.global_position)
	if off > radius:
		return null
	var start := maxf(0.0, along - sqrt(radius * radius - off * off))
	var d := start
	while d <= length:
		var p := from + dir * d
		if contains(unit, p, visual):
			return p
		d += MARCH_STEP
	return to if contains(unit, to, visual) else null


## Where a line from `from` toward the unit's centre first meets its sprite (the centre
## itself if the sprite can't be tested). Beams draw their line to here.
static func edge_point(unit: BattleUnit, from: Vector2, visual: bool = true) -> Vector2:
	var hit: Variant = first_touch(unit, from, unit.global_position, visual)
	return hit if hit != null else unit.global_position


## One frame of a homing shot: moving `step` pixels from `from` toward `target`. Returns
## where the shot hits (the first solid pixel on the way, or the target's centre if it
## gets there first), or null if it doesn't arrive this frame. `min_hit` is how close to
## the centre still counts as arriving, for sprites with see-through middles.
static func homing_hit(target: BattleUnit, from: Vector2, step: float, min_hit: float = 0.0) -> Variant:
	var centre := target.global_position
	var to_centre := centre - from
	var dist := to_centre.length()
	var end := centre if dist <= step else from + to_centre / dist * step
	var touch: Variant = first_touch(target, from, end)
	if touch != null:
		return touch
	if dist <= maxf(step, min_hit):
		return centre
	return null
