class_name GateSequenceGambit
extends Gambit
## GATE.W(A)'s base Gambit: each of its first casts summons a different Gateling beside it,
## in order (Broad, then two Slims, then Gatling, and with A1 a Chosen). Casts after the
## last one summon nothing; like every cast they still heal and boost its Gatelings
## (GatePassive). Each Gateling has its own stats plus a share of GATE.W(A)'s.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn

## What each cast summons, in order.
@export var steps: Array[UnitData] = []
## How many of each step's Gateling it summons (missing = 1).
@export var counts: Array[int] = [1, 2, 1, 1]
## How many of the steps it uses. A1 adds one.
@export var casts: int = 3
## Share of GATE.W(A)'s max health each Gateling adds to its own (0.2 = 20%).
@export_range(0.0, 1.0, 0.05) var health_share: float = 0.2
## Share of GATE.W(A)'s attributes and wards each Gateling adds to its own.
@export_range(0.0, 2.0, 0.05) var stat_share: float = 0.3

const SHARED_STATS := [Stats.Stat.MIGHT, Stats.Stat.INSIGHT, Stats.Stat.CELERITY,
		Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive or not caster.is_inside_tree():
		return
	var done := _casts_done(caster)
	_set_casts_done(caster, done + 1)
	if done >= mini(casts, steps.size()) or steps[done] == null:
		caster.show_float_text("Empower", GateRules.LIGHT)
		return
	var profile := steps[done]
	var count := counts[done] if done < counts.size() else 1
	var cells := Replicator.free_cells_near(caster.grid, caster.cell, count)
	for cell in cells:
		_summon(caster, profile, cell)
	if not cells.is_empty():
		caster.show_float_text(profile.display_name if cells.size() == 1 else "%s x%d" % [profile.display_name, cells.size()], GateRules.LIGHT)


## Casts so far this battle, kept on GATE.W(A)'s passive status (cleared every battle).
static func _casts_done(caster: BattleUnit) -> int:
	for status in caster.statuses:
		if status is GatePassive.GateStatus:
			return status.casts_done
	return int(caster.get_meta("gate_casts", 0))


static func _set_casts_done(caster: BattleUnit, value: int) -> void:
	for status in caster.statuses:
		if status is GatePassive.GateStatus:
			status.casts_done = value
			return
	caster.set_meta("gate_casts", value)


func _summon(caster: BattleUnit, profile: UnitData, cell: Vector2i) -> void:
	var gateling := UNIT_SCENE.instantiate() as BattleUnit
	gateling.setup_as_profile_summon(profile, caster, 0.0)
	gateling.summon_keeps_gambit = true
	gateling._summon_max_health = profile.max_health + caster.max_health * health_share
	for stat in Stats.Stat.values():
		var value := profile.get_base_stat(stat)
		if stat in SHARED_STATS:
			value += caster.get_stat(stat) * stat_share
		gateling._summon_stats[stat] = value
	caster.get_parent().add_child(gateling)
	gateling.place_at(cell)
	caster.get_tree().call_group("battle_manager", "add_summon", gateling)
	KeepsakeVfx.gate_glow(gateling, 0, GateRules.COLOR)
	KeepsakeVfx.missile_blast(caster.get_parent(), gateling.global_position, 30.0, GateRules.COLOR)
