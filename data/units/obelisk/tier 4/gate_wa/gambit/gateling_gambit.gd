class_name GatelingGambit
extends Gambit
## GATE.W(A) summons Gatelings beside it: small ranged fighters with a share of its max
## health and of its Might, Insight and Celerity, and its wards.
##   A: two Gatelings instead of one.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn

## How a Gateling looks and fights (name, sprite, range). Its numbers come from GATE.W(A).
@export var profile: UnitData
@export var count: int = 1
## Share of GATE.W(A)'s max health each Gateling gets (0.35 = 35%).
@export_range(0.0, 1.0, 0.05) var health_share: float = 0.35
## Share of GATE.W(A)'s Might, Insight and Celerity each Gateling gets.
@export_range(0.0, 2.0, 0.05) var stat_share: float = 0.6


func can_use(caster: BattleUnit) -> bool:
	return profile != null and not Replicator.free_cells_near(caster.grid, caster.cell, 1).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive or not caster.is_inside_tree():
		return
	var cells := Replicator.free_cells_near(caster.grid, caster.cell, count)
	for cell in cells:
		_summon(caster, cell)
	caster.show_float_text("Gateling" if cells.size() == 1 else "Gatelings x%d" % cells.size(), GateRules.LIGHT)


func _summon(caster: BattleUnit, cell: Vector2i) -> void:
	var gateling := UNIT_SCENE.instantiate() as BattleUnit
	gateling.setup_as_profile_summon(profile, caster, health_share)
	for stat in [Stats.Stat.MIGHT, Stats.Stat.INSIGHT, Stats.Stat.CELERITY]:
		gateling._summon_stats[stat] *= stat_share
	caster.get_parent().add_child(gateling)
	gateling.place_at(cell)
	caster.get_tree().call_group("battle_manager", "add_summon", gateling)
	KeepsakeVfx.missile_blast(caster.get_parent(), gateling.global_position, 30.0, GateRules.COLOR)
