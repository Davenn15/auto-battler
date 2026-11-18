class_name MatchFog
extends Node2D
## Fog over the opponent's half of the board during planning. Their last fielded army shows
## faintly underneath; before you've seen it (no combat yet), their faction's emblem does
## instead. Clears when combat starts.

const FOG_COLOR := Color(0.55, 0.57, 0.62)
const FOG_ALPHA := 0.5
const PUFFS := 26

var _grid: BattleGrid
var _cells: Array[Vector2i] = []
var _puffs: Array = []   # [position, radius, speed]
var _time := 0.0
## The opponent's faction, drawn as its emblem under the fog while their army is unseen
## ("" once it has been seen).
var _emblem_faction := ""
## The emblem's size, in pixels, and how strongly it shows through the fog.
const EMBLEM_SIZE := 120.0
const EMBLEM_ALPHA := 0.55


func _ready() -> void:
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
	_emblem_faction = faction if last_seen_round <= 0 else ""
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
	var box: Rect2 = get_meta("box")
	# Before their army has been seen: their faction's emblem, under the clouds.
	if _emblem_faction != "":
		var color: Color = RoundTrack.FACTION_COLORS.get(_emblem_faction, RoundTrack.NEUTRAL_COLOR)
		RoundTrack.draw_icon(self, RoundTrack.Kind.FACTION, _emblem_faction, to_local(box.get_center()), EMBLEM_SIZE, Color(color, EMBLEM_ALPHA))
	# Drifting clouds, wrapping around inside the fogged area.
	for puff in _puffs:
		var x := fposmod(puff[0].x - box.position.x + _time * puff[2], box.size.x) + box.position.x
		var pos := to_local(Vector2(x, puff[0].y + sin(_time * 0.5 + puff[1]) * 4.0))
		draw_circle(pos, puff[1], Color(FOG_COLOR, FOG_ALPHA * 0.35))
