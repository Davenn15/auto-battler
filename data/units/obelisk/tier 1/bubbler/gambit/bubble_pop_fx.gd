class_name BubblePopFx
extends Node2D
## A Bubbler bubble popping: a ring of orange bubble foam grows from the ally holding it out
## to the edge of the area it hits (every hex within Radius Cells), then fades. Kept quiet,
## as pops happen often.

const TIME := 0.5

var grid: BattleGrid
var center: Vector2i
var radius_cells := 1
var _age := 0.0


## Plays the pop at `unit`'s hex.
static func play(unit: BattleUnit, radius: int) -> void:
	if not KeepsakeVfx.enabled() or unit.grid == null:
		return
	var fx := BubblePopFx.new()
	fx.grid = unit.grid
	fx.center = unit.cell
	fx.radius_cells = radius
	fx.z_index = 14
	unit.get_tree().current_scene.add_child(fx)
	fx.global_position = unit.grid.cell_to_world(unit.cell)


func _process(delta: float) -> void:
	_age += delta
	if _age >= TIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var color: Color = BubbleZone.BUBBLE_COLOR
	var t := _age / TIME
	var grow := 1.0 - pow(1.0 - minf(t * 1.6, 1.0), 2.0)
	var r := grid.cell_spacing() * (radius_cells + 0.5) * grow   # the far edge of the outer hexes
	var fade := 1.0 - t
	draw_circle(Vector2.ZERO, r, Color(color, 0.05 * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(color, 0.55 * fade), 2.0, true)
	for i in 12:   # foam: little bubbles riding the ring
		var p := Vector2.from_angle(TAU * i / 12.0) * r
		draw_arc(p, 2.5 + (i % 2), 0.0, TAU, 10, Color(color, 0.45 * fade), 1.0, true)
