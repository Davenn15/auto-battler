extends Node2D

@export var unit_scene: PackedScene
@export var roster: Array[UnitData] = []
@export var grid: BattleGrid
@export var bench: HBoxContainer
@export var ui_layer: CanvasLayer

@export var player_team: int = 1

var _dragging: UnitData = null
var _drag_slot: Button = null
var _ghost: ColorRect = null

var prep_enabled: bool = true
var _drag_unit: BattleUnit = null     # set when dragging a placed unit
var _drag_origin := Vector2i(-1, -1)  # the cell it came from

func _ready() -> void:
	for unit_data in roster:
		_add_bench_slot(unit_data)

func _add_bench_slot(unit_data: UnitData) -> void:
	var slot := Button.new()
	slot.text = unit_data.display_name
	slot.custom_minimum_size = Vector2(80, 80)
	slot.button_down.connect(_start_drag.bind(unit_data, slot))
	bench.add_child(slot)

func _make_ghost() -> void:
	_ghost = ColorRect.new()
	_ghost.size = Vector2(48, 48)
	_ghost.color = Color(0.3, 0.6, 1.0, 0.7)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_ghost)

func _start_drag(unit_data: UnitData, slot: Button) -> void:
	if not prep_enabled or _dragging != null:
		return
	_dragging = unit_data
	_drag_slot = slot
	_make_ghost()

func _try_pick_up(world_pos: Vector2) -> void:
	var cell := grid.world_to_cell(world_pos)
	var unit := grid.unit_at(cell)
	if unit == null:
		return
	_dragging = unit.data
	_drag_unit = unit
	_drag_origin = cell
	grid.vacate(cell, unit)
	unit.visible = false
	_make_ghost()

func _process(_delta: float) -> void:
	if _dragging == null:
		return
	_ghost.position = get_viewport().get_mouse_position() - _ghost.size / 2.0
	var cell := grid.world_to_cell(get_global_mouse_position())
	grid.set_hover(cell if grid.can_place(cell) else Vector2i(-1, -1))

func _input(event: InputEvent) -> void:
	if not prep_enabled:
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed and _dragging == null:
		# Ignore presses that land on UI, such as the bench or Fight button.
		if get_viewport().gui_get_hovered_control() == null:
			_try_pick_up(get_global_mouse_position())
	elif not event.pressed and _dragging != null:
		_finish_drag()

func _finish_drag() -> void:
	var cell := grid.world_to_cell(get_global_mouse_position())
	var mouse := get_viewport().get_mouse_position()
	var over_bench := bench.get_global_rect().has_point(mouse)

	if _drag_unit == null:
		# Dragging from the bench.
		if grid.can_place(cell):
			_spawn_unit(_dragging, cell)
			_drag_slot.queue_free()
	else:
		# Dragging a placed unit.
		if over_bench:
			_add_bench_slot(_dragging)
			_drag_unit.queue_free()
		elif grid.can_place(cell):
			_drag_unit.place_at(cell)
			_drag_unit.visible = true
		else:
			grid.occupy(_drag_origin, _drag_unit)
			_drag_unit.visible = true

	_ghost.queue_free()
	_ghost = null
	_dragging = null
	_drag_slot = null
	_drag_unit = null
	_drag_origin = Vector2i(-1, -1)
	grid.set_hover(Vector2i(-1, -1))

func _spawn_unit(unit_data: UnitData, cell: Vector2i) -> void:
	var unit := unit_scene.instantiate() as BattleUnit
	unit.data = unit_data
	unit.team = player_team
	unit.auto_place = false          # we place it ourselves below
	grid.get_parent().add_child(unit)
	unit.place_at(cell)
