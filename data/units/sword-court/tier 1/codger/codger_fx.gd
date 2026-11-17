class_name CodgerFx
extends RefCounted
## Codger's look, shared by his passive and Gambits: a radioactive greenish yellow, and his
## bladehook on its chain.

const COLOR := Color(0.78, 0.95, 0.15)
const LIGHT := Color(0.92, 1.0, 0.55)


## The bladehook flying from `caster` to `target_pos` over `time`. Returns the hook (it
## keeps its chain drawn back to Codger) so the Gambit can reel it in; null when headless.
static func throw_hook(caster: BattleUnit, target_pos: Vector2, time: float) -> Hook:
	if not KeepsakeVfx.enabled() or not caster.is_inside_tree():
		return null
	var hook := Hook.new()
	hook.caster = caster
	hook.z_index = 14
	caster.get_parent().add_child(hook)
	hook.global_position = caster.global_position
	hook.rotation = (target_pos - caster.global_position).angle()
	hook.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS) \
			.tween_property(hook, "global_position", target_pos, time)
	return hook


## Reels the hook in over `time`, riding on `follow` (the hooked enemy, while it's valid),
## then removes it.
static func reel_in(hook: Hook, follow, time: float) -> void:
	if hook == null or not is_instance_valid(hook):
		return
	hook.follow = follow
	var tween := hook.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(time)
	tween.tween_callback(hook.queue_free)


## A rending slash across `at`, swept from `from`'s side: a curved blade-streak in his colour
## with a dark red tear left behind it, both fading quickly.
static func rend(parent: Node, from: Vector2, at: Vector2) -> void:
	if not KeepsakeVfx.enabled() or parent == null:
		return
	var facing := (at - from).angle()
	for layer in 2:
		var arc := Line2D.new()
		arc.width = 5.0 if layer == 0 else 2.5
		arc.default_color = Color(0.6, 0.05, 0.05, 0.9) if layer == 0 else LIGHT
		arc.begin_cap_mode = Line2D.LINE_CAP_ROUND
		arc.end_cap_mode = Line2D.LINE_CAP_ROUND
		for i in 9:
			var a := facing + PI * 0.5 - PI * i / 8.0
			arc.add_point(Vector2.from_angle(a) * 16.0 + Vector2.from_angle(facing) * -6.0)
		arc.z_index = 13
		parent.add_child(arc)
		arc.global_position = at
		var tween := arc.create_tween()
		tween.tween_property(arc, "modulate:a", 0.0, 0.35 if layer == 0 else 0.2)
		tween.tween_callback(arc.queue_free)


## The bladehook: a curved blade at the end of a chain running back to Codger.
class Hook extends Node2D:
	var caster   # untyped: may be freed
	var follow = null   # while reeling in, the enemy it drags (untyped: may be freed)

	func _process(_delta: float) -> void:
		if not is_instance_valid(caster):
			queue_free()
			return
		if follow != null and is_instance_valid(follow):
			global_position = follow.global_position
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(caster):
			return
		var back := to_local(caster.global_position)
		draw_line(Vector2.ZERO, back, Color(0.3, 0.32, 0.26), 3.0, true)   # the chain
		draw_dashed_line(Vector2.ZERO, back, CodgerFx.COLOR, 1.5, 4.0)
		# The blade: a hooked crescent.
		var blade := PackedVector2Array([Vector2(-2, -3), Vector2(7, -9), Vector2(12, -4),
				Vector2(9, 1), Vector2(3, -2), Vector2(2, 3)])
		draw_colored_polygon(blade, CodgerFx.COLOR)
		var outline := blade.duplicate()
		outline.append(blade[0])
		draw_polyline(outline, Color(0.1, 0.12, 0.05), 1.0, true)
