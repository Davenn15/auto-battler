class_name ComboStageStatus
extends Status
## Which part of a multi-part Gambit the unit casts next (0 = the first). Also keeps the
## constellation: a line on the ground for each blink this combo, cleared when it ends.

const LINE_COLOR := Color(0.65, 0.75, 1.0, 0.8)   # starlight
const LINE_WIDTH := 2.0
const STAR_SIZE := 4.0      # half-width of the little star at each end of a line
const FADE_DELAY := 1.0     # seconds a finished constellation stays before fading
const FADE_TIME := 0.6      # seconds it then takes to fade

var stage: int = 0
var _lines: Array[Line2D] = []


## Gambit-made statuses block charge until they end. This lasts all battle, so it mustn't.
func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


## If the unit dies mid-combo, its half-drawn constellation fades too.
func on_applied(unit: BattleUnit) -> void:
	unit.died.connect(func(_u): fade_lines())


func on_removed(_unit: BattleUnit) -> void:
	for line in _lines:
		if is_instance_valid(line):
			line.queue_free()
	_lines.clear()


## Draws a line on the ground from `from` to `to` (world positions), with a small star at
## each end. It stays until fade_lines() is called.
func add_line(unit: BattleUnit, from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.width = LINE_WIDTH
	line.default_color = LINE_COLOR
	line.z_index = -1   # on the ground, under the units
	unit.get_tree().current_scene.add_child(line)
	line.global_position = Vector2.ZERO   # so the points below can be world positions
	line.points = PackedVector2Array([from, to])
	for point in [from, to]:
		var star := Polygon2D.new()
		star.polygon = PackedVector2Array([Vector2(0, -STAR_SIZE), Vector2(STAR_SIZE * 0.5, 0),
				Vector2(0, STAR_SIZE), Vector2(-STAR_SIZE * 0.5, 0)])
		star.color = Color(LINE_COLOR, 1.0)
		star.position = point
		line.add_child(star)
	_lines.append(line)


## Fades out and removes every line drawn so far, after a short pause.
func fade_lines() -> void:
	for line in _lines:
		if is_instance_valid(line):
			var tween := line.create_tween()
			tween.tween_interval(FADE_DELAY)
			tween.tween_property(line, "modulate:a", 0.0, FADE_TIME)
			tween.tween_callback(line.queue_free)
	_lines.clear()
