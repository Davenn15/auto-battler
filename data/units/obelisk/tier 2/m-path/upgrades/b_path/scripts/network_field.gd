class_name NetworkField
extends Node2D
## M-Path's redistribution aura (see NetworkGambit): every hex within Radius Cells of him,
## moving with him. Every Interval seconds it balances the allies inside: each ends at the
## same share of its own max health (the team's total health doesn't change), then (B2) each
## heals Heal Share of its max health. Ends when time runs out or he dies. He gains no Charge
## while it lasts. Drawn as the hexes it covers, brightening on each balance.

const COLOR := Color(1.0, 0.45, 0.75)

var source   # M-Path; untyped because he may be freed
var radius_cells := 1
var time_left := 8.0
var interval := 3.0
var heal_share := 0.0
var _timer := 0.0
var _flash := 0.0   # seconds since the last balance, for the brightening
var _time := 0.0
var _lock: Status = null   # ChargeLock on M-Path while the aura lasts


func _ready() -> void:
	_timer = interval
	_flash = 99.0


## Allies (him included) standing within `radius` hexes of `unit`.
static func allies_within(unit: BattleUnit, radius: int) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other != null and other.alive and other.team == unit.team \
				and unit.grid.get_distance(unit.cell, other.cell) <= radius:
			result.append(other)
	return result


func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or not source.alive:
		end()
		return
	global_position = source.global_position
	time_left -= delta
	if time_left <= 0.0:
		end()
		return
	_timer -= delta
	if _timer <= 0.0 and source.active:
		_timer += interval
		_balance()


## Everyone inside ends at the same share of their max health; then the B2 heal.
func _balance() -> void:
	var inside := NetworkField.allies_within(source, radius_cells)
	if inside.size() < 2 and heal_share <= 0.0:
		return
	var total := 0.0
	var total_max := 0.0
	for unit in inside:
		total += unit.health
		total_max += unit.max_health
	if inside.size() >= 2 and total_max > 0.0:
		var level := total / total_max
		for unit in inside:
			unit.set_health(unit.max_health * level)
	if heal_share > 0.0:
		for unit in inside:
			unit.heal(unit.max_health * heal_share, source.get_instance_id(), true, true)
	_flash = 0.0


func lock_charge(caster: BattleUnit) -> void:
	_lock = ChargeLock.new()
	caster.add_status(_lock)


func end() -> void:
	if is_instance_valid(source) and _lock != null:
		source.remove_status(_lock)
	_lock = null
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	_flash += delta
	queue_redraw()


func _draw() -> void:
	if not KeepsakeVfx.enabled() or not is_instance_valid(source) or source.grid == null:
		return
	var grid: BattleGrid = source.grid
	var appear := clampf(time_left / 0.3, 0.0, 1.0)
	var pulse := 0.85 + 0.15 * sin(_time * 4.0)
	var bright := maxf(1.0 - _flash / 0.4, 0.0)   # brightens on each balance, then settles
	for cell in grid.all_cells():
		if grid.get_distance(source.cell, cell) > radius_cells:
			continue
		var hexagon := PackedVector2Array()
		for corner in grid.hex_corners_world(cell):
			hexagon.append(to_local(corner))
		draw_colored_polygon(hexagon, Color(COLOR, (0.16 * pulse + 0.25 * bright) * appear))
		hexagon.append(hexagon[0])
		draw_polyline(hexagon, Color(COLOR, (0.7 + 0.3 * bright) * appear), 1.5, true)


## On M-Path while his aura lasts: no Charge gain.
class ChargeLock extends Status:
	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return true
