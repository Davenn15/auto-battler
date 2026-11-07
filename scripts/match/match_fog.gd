class_name MatchFog
extends Node2D
## Fog over the opponent's half of the board during planning, with their faction and when
## their army (shown faintly underneath) was last seen. Clears when combat starts.

const FOG_COLOR := Color(0.55, 0.57, 0.62)
const FOG_ALPHA := 0.5
const PUFFS := 26

var _grid: BattleGrid
var _cells: Array[Vector2i] = []
var _puffs: Array = []   # [position, radius, speed]
var _time := 0.0
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	visible = false


func show_fog(grid: BattleGrid, faction: String, last_seen_round: int) -> void:
	_grid = grid
	_cells.clear()
	for cell in MatchRules.own_cells():
		_cells.append(MatchRules.mirror_cell(cell))
	var box := Rect2(grid.cell_to_world(_cells[0]), Vector2.ZERO)
	for cell in _cells:
		box = box.expand(grid.cell_to_world(cell))
	# Clouds drift between the outer cells' centres, small enough to stay on the fogged half.
	if _puffs.is_empty():
		for i in PUFFS:
			_puffs.append([Vector2(randf_range(box.position.x, box.end.x), randf_range(box.position.y - 6.0, box.end.y - 4.0)),
					randf_range(16.0, 28.0), randf_range(4.0, 10.0)])
	set_meta("box", box)
	box = box.grow(grid.hex_size)
	_label.text = "Opponent: %s\n%s" % [faction, "Army last seen in round %d" % last_seen_round
			if last_seen_round > 0 else "Army not seen yet"]
	_label.size = Vector2(box.size.x, 40)
	_label.position = Vector2(box.position.x, box.position.y - 44)
	modulate.a = 1.0
	visible = true
	queue_redraw()


## Clears the fog with a quick fade.
func hide_fog() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): visible = false)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _grid == null:
		return
	for cell in _cells:
		var center := to_local(_grid.cell_to_world(cell))
		var points := PackedVector2Array()
		for i in 6:
			var angle := deg_to_rad(60.0 * i - 30.0)
			points.append(center + Vector2(cos(angle), sin(angle)) * (_grid.hex_size + 0.5))
		draw_colored_polygon(points, Color(FOG_COLOR, FOG_ALPHA * 0.6))
	# Drifting clouds, wrapping around inside the fogged area.
	var box: Rect2 = get_meta("box")
	for puff in _puffs:
		var x := fposmod(puff[0].x - box.position.x + _time * puff[2], box.size.x) + box.position.x
		var pos := to_local(Vector2(x, puff[0].y + sin(_time * 0.5 + puff[1]) * 4.0))
		draw_circle(pos, puff[1], Color(FOG_COLOR, FOG_ALPHA * 0.35))
