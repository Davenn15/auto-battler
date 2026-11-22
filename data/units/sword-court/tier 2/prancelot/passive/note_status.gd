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
## Return the status it gave the target (a buff, or a debuff like Silence), and a note in
## this note's colour lingers around the target for as long as it lasts; null for none.
func _arrive(_unit, _target: BattleUnit, _strength: float) -> Status:
	return null


## Living units within range on `team`, for picking targets. Never Prancelot himself: his
## notes can't heal or buff him (no note is sent if nobody else qualifies).
func _units_in_range(unit: BattleUnit, team: int) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other != null and other != unit and other.alive and other.team == team \
				and unit.grid.get_distance(unit.cell, other.cell) <= range_cells:
			result.append(other)
	return result


## Flies a ♪ to `target` as a projectile, then calls _arrive if it's still alive. Notes
## count as projectiles for everything that cares about them: an enemy's Warding bubble
## slows them, and an enemy that sends projectiles back (Glaive's spin, a parry) can send a
## note at an enemy back at Prancelot, where it lands on him instead. Notes for allies can
## only be slowed: allies never send a note back.
func _send(unit: BattleUnit, target: BattleUnit, strength: float) -> void:
	var shot := NoteShot.new()
	shot.setup(unit, target, 0.0, Color(0, 0, 0, 0))
	shot.polygon = PackedVector2Array()   # drawn as the ♪ below, not a square
	shot.speed = NOTE_SPEED
	shot.is_attack = false
	shot.grants_charge = false
	shot.note = self
	shot.strength = strength
	shot.z_index = 15
	var glyph := Label.new()
	glyph.text = "♪"
	glyph.add_theme_font_size_override("font_size", 18)
	glyph.add_theme_color_override("font_color", color)
	glyph.add_theme_color_override("font_outline_color", Color.BLACK)
	glyph.add_theme_constant_override("outline_size", 3)
	glyph.position = Vector2(-6, -24)   # roughly centres the glyph on a unit
	shot.add_child(glyph)
	unit.get_tree().current_scene.add_child(shot)
	shot.global_position = unit.global_position
	shot.rotation = unit.global_rotation   # stays upright when the view is turned


## Untyped `unit` and `target`: either may have died while the note was in the air.
func _land(unit, target, strength: float) -> void:
	if is_instance_valid(target) and target.alive:
		var buff := _arrive(unit, target, strength)
		if buff != null:
			KeepsakeVfx.note_linger(target, buff, color)


## A note in flight. It deals no damage and isn't an attack: when it lands, the note does
## its thing to whoever it reached (after a reflect, that's Prancelot, from the reflector).
class NoteShot extends Projectile:
	var note: NoteStatus
	var strength := 1.0

	func _hit() -> void:
		if target.try_reflect(self):
			return   # flying back at Prancelot now
		note._land(instance_from_id(shooter_id), target, strength)
		queue_free()
