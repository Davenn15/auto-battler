class_name BellowGambit
extends Gambit
## Bellows: allies within range gain Might and enemies within range lose it, for a while.

const BELLOW_COLOR := Color(1.0, 0.75, 0.3)

## Range in hex cells, measured from the caster.
@export var range_cells: int = 2
@export var ally_might_bonus: float = 40.0
@export var enemy_might_reduction: float = 30.0
## Seconds the effects last.
@export var duration: float = 5.0
## Gives the caster and the allies it buffs the regen the caster's passive gives at
## zero health, for the duration.
@export var grant_max_regen: bool = false
## Damage dealt to each enemy in range. Total = Damage + Might Scaling × Might.
@export var damage: float = 60.0
@export var might_scaling: float = 0.5
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0


## Only bellows if someone is in range, so charge isn't wasted.
func can_use(caster: BattleUnit) -> bool:
	return not _units_in_range(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var id := caster.get_instance_id()
	var regen := _max_passive_regen(caster) if grant_max_regen else 0.0
	caster.show_float_text("Bellow", BELLOW_COLOR)
	KeepsakeVfx.bellow_ring(caster, range_cells)
	var hit_damage := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	# Items can let the damage and the Might cut wrack: one roll each for the whole bellow.
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit_damage *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	var might_cut := enemy_might_reduction * caster.wrack_effect_multiplier(Stats.EffectKind.CONTROL)
	for unit in _units_in_range(caster):
		if unit.team == caster.team:
			_apply(unit, BellowedStatus.new(id, ally_might_bonus, regen, duration))
		else:
			var dealt := unit.take_damage(hit_damage, wrack, damage_type)
			caster.get_tree().call_group("damage_tracker", "record_damage", id, dealt)
			if unit.alive:   # the hit may have killed it
				_apply(unit, BellowedStatus.new(id, -might_cut, 0.0, duration))


## Replaces this caster's earlier Bellow on `unit` instead of stacking.
func _apply(unit: BattleUnit, status: BellowedStatus) -> void:
	for old in unit.statuses.duplicate():
		if old is BellowedStatus and old.source_id == status.source_id:
			unit.remove_status(old)
	unit.add_status(status)


## Every living unit other than the caster within range, on either team.
func _units_in_range(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit == caster or not unit.alive:
			continue
		if caster.grid.get_distance(caster.cell, unit.cell) <= range_cells:
			result.append(unit)
	return result


## The regen the caster's low-health passive gives at zero health, so the two stay in step.
func _max_passive_regen(caster: BattleUnit) -> float:
	for status in caster.statuses:
		if status is LowHealthRegenStatus:
			return status.max_bonus
	return 0.0
