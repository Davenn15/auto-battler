class_name BarrageGambit
extends Gambit
## BAR.RAJ launches a barrage of missiles. Each one picks a random enemy within Range Cells,
## follows it, and explodes on it, damaging every enemy within Blast Cells of where it lands.
## Damage per missile per enemy = Damage + Might Scaling x Might.
##   A2: more missiles.  A1: bigger blasts.

## How far away the enemies it aims at can be, in hex cells.
@export var range_cells: int = 5
@export var missiles: int = 8
## Seconds between missiles.
@export var interval: float = 0.08
## Blast radius of each missile, in hex cells (0.8 = most of a cell).
@export var blast_cells: float = 0.8
@export var damage: float = 60.0
@export var might_scaling: float = 0.4
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0


func can_use(caster: BattleUnit) -> bool:
	return not _enemies_in_range(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var enemies := _enemies_in_range(caster)
	if enemies.is_empty():
		return
	var hit := Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	var blast := blast_cells * caster.grid.cell_spacing()
	for i in missiles:
		var target: BattleUnit = CombatRng.pick(enemies)
		var level := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
		var amount := hit * caster.effect_wrack_multiplier(level, Stats.EffectKind.GAMBIT_DAMAGE)
		fire(caster, target, blast, amount, damage_type, level, i * interval)
	caster.show_float_text("Barrage", BarrageMissile.COLOR)


## Launches one missile from `caster` at `target`, following it until it lands.
static func fire(caster: BattleUnit, target: BattleUnit, blast: float, amount: float, type: int,
		level: int, delay: float) -> void:
	var missile := BarrageMissile.new()
	missile.setup(caster, caster.global_position, target.global_position, blast, amount, type, level, delay)
	missile.target_unit = target
	caster.get_tree().current_scene.add_child(missile)
	missile.global_position = caster.global_position


func _enemies_in_range(caster: BattleUnit) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team != caster.team and unit.is_targetable() \
				and caster.grid.get_distance(caster.cell, unit.cell) <= range_cells:
			result.append(unit)
	return result
