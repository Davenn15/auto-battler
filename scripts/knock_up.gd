class_name KnockUp
extends RefCounted
## The Knock-up keyword: the unit is thrown into the air, stunned for the duration (it
## can't move, attack or cast). It's crowd control like a stun: Immovability shortens it,
## 100 or more ignores it, and an item that lets control effects wrack lengthens it.
## BYTE's ripple uses it.
##
## On screen the unit's sprite lifts up and drops back down. The lift moves the sprite's
## drawing offset, which nothing else animates, and shots still hit the unit where it
## stands at rest (SpriteEdge), so the lift is only a picture.

const COLOR := Color(0.55, 0.75, 1.0)   # a light sky blue
const LIFT := 16.0           # pixels the sprite rises
const RISE_SHARE := 0.3      # share of the knock-up spent rising
const FALL_SHARE := 0.3      # share spent dropping back down


## Knocks `target` up for `duration` seconds. `source` (optional) is who did it: its items
## may wrack it longer. Returns how long the target is actually knocked up (0 if it didn't
## land: immune, dead).
static func apply(target: BattleUnit, duration: float, source = null) -> float:
	if target == null or not is_instance_valid(target) or not target.alive or duration <= 0.0:
		return 0.0
	if target.is_cc_immune():
		target.stun(duration, source)   # shows "Immune"
		return 0.0
	target.stun(duration, source)
	var landed := maxf(target._stunned_time, 0.0)   # a longer stun it already had wins
	target.show_float_text("Knocked up", COLOR)
	_lift(target, landed)
	return landed


## The sprite rising and falling over `time`.
static func _lift(target: BattleUnit, time: float) -> void:
	if not KeepsakeVfx.enabled() or target.sprite == null or time <= 0.0:
		return
	var sprite := target.sprite
	var scale_y := absf(sprite.scale.y) if sprite.scale.y != 0.0 else 1.0
	var up := Vector2(0, -LIFT / scale_y)   # offset is in the texture's own pixels
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "offset", up, time * RISE_SHARE).as_relative() \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(time * (1.0 - RISE_SHARE - FALL_SHARE))
	tween.tween_property(sprite, "offset", -up, time * FALL_SHARE).as_relative() \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
