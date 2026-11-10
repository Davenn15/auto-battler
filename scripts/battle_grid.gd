@tool
class_name BattleGrid
extends Node2D
## Pointy-top hex grid using axial coordinates (q = Vector2i.x, r = Vector2i.y).
## Owns three things: coordinate conversion, pathfinding, and who stands where.

@export var columns: int = 8:
	set(value):
		columns = maxi(value, 1)
		_rebuild()
@export var rows: int = 8:
	set(value):
		rows = maxi(value, 1)
		_rebuild()
@export var hex_size: float = 32.0:   # center-to-corner distance in pixels
	set(value):
		hex_size = maxf(value, 1.0)
		_rebuild()
@export var show_debug: bool = true:  # draws hex outlines
	set(value):
		show_debug = value
		queue_redraw()

## Faint colour over each half of the board: blue for the bottom (your) half, red for the top.
@export var tint_halves: bool = true:
	set(value):
		tint_halves = value
		queue_redraw()
const BOTTOM_TINT := Color(0.3, 0.5, 1.0, 0.08)
const TOP_TINT := Color(1.0, 0.3, 0.3, 0.08)

const SQRT3 := 1.7320508075688772
# The six axial neighbor offsets.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]

var _astar := AStar2D.new()
var _ids: Dictionary = {}          # Vector2i cell -> int astar id
var _cells_by_id: Dictionary = {}  # int astar id -> Vector2i cell
var _occupants: Dictionary = {}    # Vector2i cell -> BattleUnit
var _hover_cell := Vector2i(-1, -1)   # cell to highlight; (-1, -1) is off-grid, so "none"
var _built := false


func _enter_tree() -> void:
	add_to_group("battle_grid")   # units find the grid through this group


func _ready() -> void:
	_ensure_built()
	queue_redraw()


# Throws away the built grid so it regenerates with the new settings.
# This also clears occupancy, so it's meant for editing, not for use mid-battle.
func _rebuild() -> void:
	_astar.clear()
	_ids.clear()
	_cells_by_id.clear()
	_occupants.clear()
	_built = false
	if is_inside_tree():   # setters also fire while the scene is loading, before we're ready
		_ensure_built()
		queue_redraw()


# Units call into the grid during their own _ready(), which may run before ours,
# so every public method makes sure the grid exists first.
func _ensure_built() -> void:
	if _built:
		return
	_built = true

	var id := 0
	for r in rows:
		# Shifting q's start by floor(r/2) turns the skewed axial layout
		# into a rectangle on screen.
		var q_start := -floori(r / 2.0)
		for i in columns:
			var cell := Vector2i(q_start + i, r)
			_ids[cell] = id
			_cells_by_id[id] = cell
			_astar.add_point(id, cell_to_local(cell))
			id += 1

	for cell in _ids:
		for dir in DIRECTIONS:
			var neighbor: Vector2i = cell + dir
			# Only connect once per pair (connect_points is bidirectional).
			if _ids.has(neighbor) and _ids[neighbor] > _ids[cell]:
				_astar.connect_points(_ids[cell], _ids[neighbor])


# ---------- Coordinate conversion ----------

func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(
		hex_size * (SQRT3 * cell.x + SQRT3 / 2.0 * cell.y),
		hex_size * 1.5 * cell.y)


func local_to_cell(p: Vector2) -> Vector2i:
	var q := (SQRT3 / 3.0 * p.x - p.y / 3.0) / hex_size
	var r := (2.0 / 3.0 * p.y) / hex_size
	return _axial_round(q, r)

func cell_spacing() -> float:
	return hex_size * SQRT3

func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(cell_to_local(cell))


func world_to_cell(p: Vector2) -> Vector2i:
	return local_to_cell(to_local(p))


# Fractional axial coords -> nearest whole hex, via cube coordinates (q + r + s = 0).
func _axial_round(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	# Fix whichever coordinate was rounded the most so the sum stays zero.
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


# ---------- Queries ----------

func has_cell(cell: Vector2i) -> bool:
	_ensure_built()
	return _ids.has(cell)


func get_distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	@warning_ignore("integer_division")
	return (absi(dq) + absi(dq + dr) + absi(dr)) / 2


func is_occupied(cell: Vector2i) -> bool:
	return _occupants.has(cell)


## The unit standing in `cell`, or null. The explicit return type is what lets
## callers write `var unit := grid.unit_at(cell)` without a type-inference error.
func unit_at(cell: Vector2i) -> BattleUnit:
	return _occupants.get(cell) as BattleUnit


## True if `cell` exists and nobody is standing in it.
func can_place(cell: Vector2i) -> bool:
	return has_cell(cell) and not is_occupied(cell)


## Highlights one cell (used while dragging). Pass an off-grid cell to clear it.
func set_hover(cell: Vector2i) -> void:
	if cell == _hover_cell:
		return
	_hover_cell = cell
	queue_redraw()


# ---------- Occupancy ----------

func occupy(cell: Vector2i, unit: Node) -> void:
	_ensure_built()
	_occupants[cell] = unit
	_astar.set_point_disabled(_ids[cell], true)   # pathfinding now routes around it


func vacate(cell: Vector2i, unit: Node) -> void:
	# Only release the cell if this unit is the one holding it.
	if _occupants.get(cell) == unit:
		_occupants.erase(cell)
		_astar.set_point_disabled(_ids[cell], false)


## Frees every cell, for when the whole board is cleared and set up again.
func clear_occupants() -> void:
	for cell in _occupants.keys():
		_astar.set_point_disabled(_ids[cell], false)
	_occupants.clear()


# ---------- Pathfinding ----------

## Returns the next cell to step into on the way from `from` to `to`,
## or `from` itself if there is no path (e.g. fully blocked).
func get_next_step(from: Vector2i, to: Vector2i) -> Vector2i:
	_ensure_built()
	if not _ids.has(from) or not _ids.has(to):
		return from

	var from_id: int = _ids[from]
	var to_id: int = _ids[to]

	# The mover and its target both occupy their cells (so both are disabled).
	# A* can't start or end on a disabled point, so enable them for this query only.
	var from_was_disabled := _astar.is_point_disabled(from_id)
	var to_was_disabled := _astar.is_point_disabled(to_id)
	_astar.set_point_disabled(from_id, false)
	_astar.set_point_disabled(to_id, false)
	var path := _astar.get_id_path(from_id, to_id)
	_astar.set_point_disabled(from_id, from_was_disabled)
	_astar.set_point_disabled(to_id, to_was_disabled)

	if path.size() < 2:
		return from
	return _cells_by_id[path[1]]   # path[0] is `from`


# ---------- Debug drawing ----------

func _hex_points(cell: Vector2i, count: int) -> PackedVector2Array:
	var center := cell_to_local(cell)
	var points := PackedVector2Array()
	for i in count:
		var angle := deg_to_rad(60.0 * i - 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * hex_size)
	return points


func _draw() -> void:
	if show_debug and tint_halves:
		# Team 1's half (the bottom rows) blue, team 2's red; swapped while the battle is
		# watched turned around, so your own half is always the blue one.
		var swap := not Engine.is_editor_hint() and BattleUnit.swap_team_colors
		for cell in _ids:
			var bottom: bool = cell.y >= rows / 2
			draw_colored_polygon(_hex_points(cell, 6), BOTTOM_TINT if bottom != swap else TOP_TINT)
	if show_debug:
		for cell in _ids:
			draw_polyline(_hex_points(cell, 7), Color(1, 1, 1, 0.25), 1.0)   # 7 points closes it
	if _ids.has(_hover_cell):
		draw_colored_polygon(_hex_points(_hover_cell, 6), Color(0.3, 0.6, 1.0, 0.35))

## Free cells within `range_cells` of `center`: spots a unit could attack from.
func free_cells_in_range(center: Vector2i, range_cells: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dq in range(-range_cells, range_cells + 1):
		for dr in range(-range_cells, range_cells + 1):
			var c := center + Vector2i(dq, dr)
			if get_distance(center, c) <= range_cells and can_place(c):
				result.append(c)
	return result
