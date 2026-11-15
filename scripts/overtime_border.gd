class_name OvertimeBorder
extends Node2D
## A ring of flames around the edge of the board while overtime lasts. BattleManager adds
## one to the grid when overtime starts; it fades in, and fades out and frees itself once
## the battle ends (or overtime is otherwise over).
## Purely visual, so its flicker runs on real time.

## Axial step to the neighbour across each hex edge: edge i runs from corner i to corner
## i + 1 and faces 60 * i degrees (corners sit at 60 * i - 30, pointy-top hexes).
const NEIGHBOURS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]
## Flame tongues per hex edge.
const TONGUES_PER_EDGE := 4
const FADE_TIME := 0.6
const DEEP := Color(0.85, 0.12, 0.02)
const MID := Color(1.0, 0.45, 0.05)
const CORE := Color(1.0, 0.85, 0.3)

var manager: BattleManager
var _grid: BattleGrid
var _edges: Array = []   # [from, to, outward normal], in the grid's local space
var _time := 0.0
var _alpha := 0.0
var _leaving := false


## Adds a border to `grid` for `p_manager`'s overtime.
static func spawn(grid: BattleGrid, p_manager: BattleManager) -> OvertimeBorder:
	var border := OvertimeBorder.new()
	border.manager = p_manager
	border._grid = grid
	border.z_index = 0   # drawn right after the board, so units stay on top
	grid.add_child(border)
	return border


func _ready() -> void:
	_build_edges()


## Every hex edge with no board cell on its far side: the outline of the board.
func _build_edges() -> void:
	_edges.clear()
	for cell in _grid.all_cells():
		var centre := _grid.cell_to_local(cell)
		for i in 6:
			if _grid.has_cell(cell + NEIGHBOURS[i]):
				continue
			var a := centre + _corner(i)
			var b := centre + _corner(i + 1)
			_edges.append([a, b, Vector2.from_angle(deg_to_rad(60.0 * i))])


func _corner(i: int) -> Vector2:
	return Vector2.from_angle(deg_to_rad(60.0 * i - 30.0)) * _grid.hex_size


func _process(delta: float) -> void:
	_time += delta
	if not is_instance_valid(manager) or not manager.in_overtime \
			or manager.phase != BattleManager.Phase.COMBAT:
		_leaving = true
	_alpha = move_toward(_alpha, 0.0 if _leaving else 1.0, delta / FADE_TIME)
	if _leaving and _alpha <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var h := _grid.hex_size
	for e in _edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var n: Vector2 = e[2]
		# A hot glowing line along the edge itself.
		draw_line(a, b, Color(DEEP, 0.55 * _alpha), h * 0.28, true)
		draw_line(a, b, Color(MID, 0.8 * _alpha), h * 0.1, true)
		# Flame tongues licking outward, each flickering on its own phase.
		for k in TONGUES_PER_EDGE:
			var t := (k + 0.5) / TONGUES_PER_EDGE
			var base := a.lerp(b, t)
			var phase := base.x * 0.071 + base.y * 0.113
			var flick := 0.55 + 0.25 * sin(_time * 9.0 + phase * 7.0) + 0.2 * sin(_time * 15.3 + phase * 3.0)
			var height := h * (0.35 + 0.35 * flick)
			var half := (b - a).length() / TONGUES_PER_EDGE * 0.75
			var side := (b - a).normalized()
			var sway := side * sin(_time * 6.0 + phase * 5.0) * h * 0.08
			_tongue(base, n, side, half, height, sway, DEEP, 0.75)
			_tongue(base, n, side, half * 0.6, height * 0.7, sway * 0.7, MID, 0.85)
			_tongue(base, n, side, half * 0.3, height * 0.4, sway * 0.4, CORE, 0.9)


## One flame tongue: a curved teardrop from `base` pointing along `n`.
func _tongue(base: Vector2, n: Vector2, side: Vector2, half: float, height: float,
		sway: Vector2, color: Color, alpha: float) -> void:
	var tip := base + n * height + sway
	# Bulges out above the base, then narrows to the tip, so it reads as a flame, not a spike.
	var points := PackedVector2Array([
		base - side * half * 0.8,
		base - side * half * 1.05 + n * height * 0.22 + sway * 0.15,
		base - side * half * 0.8 + n * height * 0.5 + sway * 0.45,
		base - side * half * 0.3 + n * height * 0.8 + sway * 0.8,
		tip,
		base + side * half * 0.3 + n * height * 0.8 + sway * 0.8,
		base + side * half * 0.8 + n * height * 0.5 + sway * 0.45,
		base + side * half * 1.05 + n * height * 0.22 + sway * 0.15,
		base + side * half * 0.8,
	])
	draw_colored_polygon(points, Color(color, alpha * _alpha))
