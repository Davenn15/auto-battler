class_name NoteStatus
extends Status
## Base for Prancelot's music notes. Every `every` attacks, a note flies to a target and
## does something when it arrives. Each kind of note extends this and fills in
## _pick_target and _arrive. Notes get stronger while a status with note_potency is on
## the unit (his Gambit).

const NOTE_SPEED := 300.0   # pixels/sec

var every: int
var range_cells: int
var color: Color = Color.WHITE
var _swings: int = 0


func _init(p_every: int, p_range_cells: int) -> void:
	every = p_every
	range_cells = p_range_cells


func on_attack(unit: BattleUnit) -> void:
	_swings += 1
	if _swings < every:
		return
	_swings = 0
	var target := _pick_target(unit)
	if target != null:
		_send(unit, target, potency(unit))


## How strong notes are right now: 1, times any note_potency the unit's statuses give.
static func potency(unit: BattleUnit) -> float:
	var total := 1.0
	for status in unit.statuses:
		if "note_potency" in status:
			total *= status.note_potency
	return total


## Override: who this note goes to, or null to skip it.
func _pick_target(_unit: BattleUnit) -> BattleUnit:
	return null


## Override: what the note does when it lands. `strength` is its potency when sent.
func _arrive(_unit, _target: BattleUnit, _strength: float) -> void:
	pass


## Living units within range on `team`, for picking targets.
func _units_in_range(unit: BattleUnit, team: int) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other != null and other.alive and other.team == team \
				and unit.grid.get_distance(unit.cell, other.cell) <= range_cells:
			result.append(other)
	return result


## Flies a ♪ to `target`, then calls _arrive if it's still alive.
func _send(unit: BattleUnit, target: BattleUnit, strength: float) -> void:
	var note := Label.new()
	note.text = "♪"
	note.add_theme_font_size_override("font_size", 18)
	note.add_theme_color_override("font_color", color)
	note.add_theme_color_override("font_outline_color", Color.BLACK)
	note.add_theme_constant_override("outline_size", 3)
	note.z_index = 15
	unit.get_tree().current_scene.add_child(note)
	var offset := Vector2(-6, -24)   # roughly centres the glyph on a unit
	note.global_position = unit.global_position + offset
	note.pivot_offset = -offset   # turns about the unit, so it stays upright when the view is turned
	note.rotation = unit.global_rotation
	var time := unit.global_position.distance_to(target.global_position) / NOTE_SPEED
	var tween := note.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(note, "global_position", target.global_position + offset, time)
	tween.tween_callback(_land.bind(note, unit, target, strength))


## Untyped `unit` and `target`: either may have died while the note was in the air.
func _land(note: Label, unit, target, strength: float) -> void:
	note.queue_free()
	if is_instance_valid(target) and target.alive:
		_arrive(unit, target, strength)
