class_name CtrlSiphonGambit
extends Gambit
## Controller's base Gambit: launches siphon drones at the enemies in range with the most
## health, one each (doubling up if there are fewer enemies). Each beams away a share of
## its enemy's max health, then flies back and heals Controller that much (see CtrlDrones).

## Drones per cast.
@export var drones: int = 2
## Share of each enemy's max health a drone drains.
@export_range(0.0, 1.0, 0.01) var drain_share: float = 0.08
## How far the enemies can be, in hex cells.
@export var range_cells: int = 3


func can_use(caster: BattleUnit) -> bool:
	return not CtrlDrones.enemies_in_range(caster, range_cells).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	for victim in CtrlDrones.siphon_targets(caster, range_cells, drones):
		CtrlDrones.launch_siphon(caster, victim, drain_share, range_cells)
	caster.show_float_text("Siphon", CtrlDrones.COLOR)
