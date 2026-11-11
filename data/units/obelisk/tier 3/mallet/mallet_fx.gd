class_name MalletFx
extends RefCounted
## MALLET's look, shared by its Gambits: a pinkish crimson, its leaps and its landings.

const COLOR := Color(0.86, 0.12, 0.33)
const LIGHT := Color(1.0, 0.5, 0.64)


## Flies `unit` to `dest` (or hops in place) over `time`, its sprite arcing up `height`
## pixels and back down. Untargetable while airborne. Await it.
static func leap(unit: BattleUnit, dest: Vector2i, time: float, height: float) -> void:
	var airborne := UntargetableStatus.new(INF)   # removed by hand on landing
	unit.add_status(airborne)
	unit.lock_for(time + 0.05)
	if unit.sprite != null:
		var hop := unit.sprite.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		hop.tween_property(unit.sprite, "position:y", -height, time * 0.5).as_relative() \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(unit.sprite, "position:y", height, time * 0.5).as_relative() \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if dest != unit.cell:
		await unit.dash_to(dest, time)
	else:
		await unit.get_tree().create_timer(time, true, true).timeout
	if is_instance_valid(unit):
		unit.remove_status(airborne)


## A crimson shockwave the size of `radius_cells`, bursting out from `unit`.
static func shockwave(unit: BattleUnit, radius_cells: int) -> void:
	if not KeepsakeVfx.enabled():
		return
	var r := (radius_cells + 0.5) * unit.grid.cell_spacing()
	KeepsakeVfx.missile_blast(unit.get_parent(), unit.global_position, r, COLOR)
	var ring := Line2D.new()
	ring.width = 5.0
	ring.default_color = LIGHT
	var points := PackedVector2Array()
	for i in 33:
		points.append(Vector2.from_angle(TAU * i / 32.0) * r)
	ring.points = points
	ring.scale = Vector2.ONE * 0.2
	ring.z_index = 14
	unit.get_parent().add_child(ring)
	ring.global_position = unit.global_position
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE, 0.25)
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(ring.queue_free)


## Phases `unit` for `time` seconds (see PhaseStatus). Its own Phase, so crowd control
## resistance doesn't shorten it.
static func self_phase(unit: BattleUnit, time: float) -> void:
	PhaseStatus.phase(unit, time)
