class_name VacuumGambit
extends Gambit
## Recycloid channels a life-draining vacuum on the enemy with the most health near him,
## dealing a share of its max health every second while it lasts. He can't move, attack or
## gain Charge while channelling.
##   Draining (A): if a target dies during the channel, he gets a burst of Charge.
##   A1: a little less damage, but it drains the two healthiest enemies at once.
##   A2: a target pushed below Execute Threshold of its max health dies outright.

## How close an enemy must be to be drained, in hex cells.
@export var range_cells: int = 3
@export var duration: float = 4.0
## Share of each target's max health dealt per second (0.03 = 3%).
@export var damage_per_second: float = 0.03
## Multiplies that damage (A1 lowers it).
@export var damage_multiplier: float = 1.0
@export var targets: int = 1
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 1
## Draining (A): Charge he gains when a target dies during the channel. 0 = none.
@export var charge_on_kill: float = 0.0
## A2: share of max health below which a target is executed (0.12 = 12%). 0 = never.
@export var execute_threshold: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	return not _targets(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var picked := _targets(caster)
	if picked.is_empty():
		return
	caster.lock_for(duration)   # channelling: no moving, attacking or Charge
	var vacuum := VacuumChannel.new()
	vacuum.caster = caster
	vacuum.set_targets(picked)
	vacuum.time_left = duration
	vacuum.damage_per_second = damage_per_second * damage_multiplier
	vacuum.damage_type = damage_type
	vacuum.charge_on_kill = charge_on_kill
	vacuum.execute_threshold = execute_threshold
	caster.get_tree().current_scene.add_child(vacuum)
	caster.show_float_text("Vacuum", VacuumChannel.VACUUM_COLOR)


## The `targets` enemies within range with the most health right now.
func _targets(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team and unit.is_targetable() \
				and caster.grid.get_distance(caster.cell, unit.cell) <= range_cells:
			result.append(unit)
	result.sort_custom(func(a, b): return a.health > b.health)
	return result.slice(0, targets)
