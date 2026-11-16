class_name FrontRowsShieldEffect
extends Passive
## An Ascension effect (Shield Wall): a unit that starts combat in its side's front two
## rows gains a Shield of Share of its max health for Duration seconds. Summons that
## arrive later in the fight don't.

@export_range(0.0, 1.0, 0.01) var share: float = 0.1
@export var duration: float = 5.0
## How many rows from the middle of the board count as the front.
@export var rows: int = 2


func on_battle_start(unit: BattleUnit) -> void:
	var manager := unit.get_tree().get_first_node_in_group("battle_manager") as BattleManager
	if manager != null and manager.combat_time > 0.0:
		return   # a summon arriving mid-fight: only the start of combat counts
	if in_front_rows(unit, rows):
		unit.add_shield(unit.max_health * share, duration, unit.get_instance_id())


## True if `unit` stands within `count` rows of the middle of the board, on its own half.
static func in_front_rows(unit: BattleUnit, count: int) -> bool:
	var middle := floori(unit.grid.rows / 2.0)
	if unit.cell.y >= middle:   # the bottom half: the front is the top of it
		return unit.cell.y < middle + count
	return unit.cell.y >= middle - count
