class_name RecyclePassive
extends Passive
## Whenever any unit, ally or enemy, dies within Range Cells of Recycloid, he sucks up a share
## of its max health and gives it to the most hurt ally near him (himself included). If
## everyone near him is at full health, it goes to a random one of them instead.
## He also remembers the last of his allies to die, for his Repurposed upgrade.

@export var range_cells: int = 3
## Share of the dead unit's max health given away (0.25 = 25%).
@export var share: float = 0.25


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(RecycleStatus.new(range_cells, share))
