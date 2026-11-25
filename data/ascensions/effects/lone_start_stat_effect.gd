class_name LoneStartStatEffect
extends Passive
## An Ascension effect (Knight Errant): a unit that starts combat with no allies in the
## cells next to it gains a stat for the whole combat.

@export var stat: Stats.Stat = Stats.Stat.CELERITY
@export var amount: float = 20.0


func on_battle_start(unit: BattleUnit) -> void:
	if not has_adjacent_ally(unit):
		unit.add_status(BonusStatus.new(stat, amount))


## True if a living ally of `unit` stands in a cell next to it.
static func has_adjacent_ally(unit: BattleUnit) -> bool:
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other != null and other != unit and other.alive and other.team == unit.team \
				and unit.grid.get_distance(unit.cell, other.cell) == 1:
			return true
	return false


class BonusStatus extends Status:
	var stat: Stats.Stat
	var amount: float

	func _init(p_stat: Stats.Stat, p_amount: float) -> void:
		stat = p_stat
		amount = p_amount

	func modify_stat(_unit: BattleUnit, which: Stats.Stat, value: float) -> float:
		return value + amount if which == stat else value

	## While planning: a faint gold circle with crossed swords on the unit's hex, so you
	## can see which units will get the bonus where they stand.
	func on_applied(unit: BattleUnit) -> void:
		if unit.previewing and KeepsakeVfx.enabled() and unit.grid != null:
			var marker := LoneMarker.new()
			marker.unit = unit
			KeepsakeVfx._ground(unit).add_child(marker)
			marker.global_position = unit.grid.cell_to_world(unit.cell)


## The planning marker: under the unit, on its hex. Goes away with the unit, or when
## combat starts (the unit stops previewing).
class LoneMarker extends Node2D:
	const GOLD := Color(1.0, 0.82, 0.3)
	var unit   # untyped: freed when the board is rebuilt

	func _process(_delta: float) -> void:
		if not is_instance_valid(unit) or not unit.previewing or not unit.is_inside_tree():
			queue_free()
			return
		global_position = unit.grid.cell_to_world(unit.cell)

	func _draw() -> void:
		var r: float = unit.grid.hex_size * 0.72 if is_instance_valid(unit) else 23.0
		draw_circle(Vector2.ZERO, r, Color(GOLD, 0.09))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(GOLD, 0.45), 1.5, true)
		for side in [-1.0, 1.0]:   # two swords crossed in an X, points up
			var dir := Vector2(side * 0.62, -0.78).normalized()
			var tip := dir * r * 0.78
			var hilt := -dir * r * 0.42
			var guard := -dir * r * 0.22
			var across := dir.orthogonal() * r * 0.2
			draw_line(guard, tip, Color(GOLD, 0.5), 2.0, true)              # blade
			draw_line(guard - across, guard + across, Color(GOLD, 0.5), 2.0, true)   # crossguard
			draw_line(guard, hilt, Color(GOLD, 0.45), 1.5, true)            # grip
			draw_circle(hilt, 1.8, Color(GOLD, 0.5))                       # pommel
