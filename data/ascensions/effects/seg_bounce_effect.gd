class_name SegBounceEffect
extends Passive
## Fault's hero Ascension: its Gambit's projectiles bounce off the edge of the board
## once. Ion Salvo bolts (the base Gambit and A) hit their target, fly on to the edge, bounce
## and can hit the first enemy on their way back. B's Ion Cannon orb bounces at the edge and
## flies back across the board, hitting enemies again (with B2 it detonates at both edges).
## The bolts and orb check has_on() when they're fired; bounce_dir() and edge_from() are the
## shared geometry.


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BounceMarker.new())


## True if `unit` has the Ascension.
static func has_on(unit) -> bool:
	if not is_instance_valid(unit) or not (unit is BattleUnit):
		return false
	for status in unit.statuses:
		if status is BounceMarker:
			return true
	return false


## The direction after bouncing off the board's edge at `at` while travelling along `dir`:
## each part of the direction that would carry it off the board is turned around.
static func bounce_dir(grid: BattleGrid, at: Vector2, dir: Vector2) -> Vector2:
	var step := grid.cell_spacing() * 0.5
	var result := dir
	if not grid.has_cell(grid.world_to_cell(at + Vector2(dir.x * step, 0.0))):
		result.x = -result.x
	if not grid.has_cell(grid.world_to_cell(at + Vector2(0.0, dir.y * step))):
		result.y = -result.y
	if result == dir:
		result = -dir   # a corner the tests missed: straight back
	return result.normalized()


## Where a line from `from` along `dir` leaves the board.
static func edge_from(grid: BattleGrid, from: Vector2, dir: Vector2) -> Vector2:
	var spacing := grid.cell_spacing()
	var edge := from
	var at := from
	for i in 400:
		at += dir * spacing * 0.25
		if not grid.has_cell(grid.world_to_cell(at)):
			break
		edge = at
	return edge


class BounceMarker extends Status:
	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false
