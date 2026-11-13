class_name SeedGambit
extends Gambit
## REPL\K8R's base Gambit: plants a replication seed in the nearby ally (not a REPL\K8R)
## with the lowest health. The seed hatches after Gestation seconds, or sooner if that ally
## dies, and a REPLK4NT (a summon with its own Gambit) spawns next to it. The longer the
## seed gestates, the more of its health the REPLK4NT starts with.
##   A (Infectious): the seed raises its host's health regen.
##   A1: a REPLK4NT that dies plants a new seed in the nearby ally with the lowest health.
##   A2: REPLK4NT attacks give Mono-Virus.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn

## The REPLK4NT that hatches: its own look, stats and Gambit.
@export var profile: UnitData
## How close the ally must be, in hex cells.
@export var range_cells: int = 3
## Seconds until the seed hatches on its own.
@export var gestation: float = 8.0
## REPLK4NTs per seed.
@export var hatch_count: int = 1
## Share of REPL\K8R's max health the REPLK4NT adds to its own, and of its attributes and wards.
@export_range(0.0, 1.0, 0.05) var health_share: float = 0.3
@export_range(0.0, 1.0, 0.05) var stat_share: float = 0.3
## Share of its max health the REPLK4NT starts with: Min if it hatches at once, rising to
## 1 (full) at full gestation.
@export_range(0.0, 1.0, 0.05) var min_start_health: float = 0.3
@export_group("Infectious (A)")
## A: health regen the seed's host gains while it carries it. 0 = none.
@export var seed_regen: float = 0.0
## A1: 1 = a REPLK4NT that dies plants a new seed.
@export var replant_on_death: float = 0.0
## A2: Mono-Virus stacks each REPLK4NT attack gives. 0 = none.
@export var virus_stacks: int = 0

const SHARED_STATS := [Stats.Stat.MIGHT, Stats.Stat.INSIGHT, Stats.Stat.CELERITY,
		Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]


func can_use(caster: BattleUnit) -> bool:
	return pick_host(caster, caster.cell, range_cells) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	plant(caster, snapshot(caster), caster.cell)


## What a REPLK4NT needs from REPL\K8R, taken now so a seed planted later (A1, by a dying
## REPLK4NT) still has it after REPL\K8R is gone.
func snapshot(caster: BattleUnit) -> Dictionary:
	var stats := {}
	for stat in SHARED_STATS:
		stats[stat] = caster.get_stat(stat)
	return {"team": caster.team, "credit": caster.get_credit_id(), "parent": caster.get_parent(),
			"max_health": caster.max_health, "stats": stats}


## Plants a seed from `unit` (REPL\K8R or a dying REPLK4NT) in the best host near `from`,
## carrying `owner` (a snapshot). With `replanting` (A1, from a dying REPLK4NT) it never
## picks another REPLK4NT, so seeds can't chain through REPLK4NTs alone.
## Returns false if there was nobody to plant it in.
func plant(unit: BattleUnit, owner: Dictionary, from: Vector2i, replanting: bool = false) -> bool:
	var host := pick_host(unit, from, range_cells, profile if replanting else null)
	if host == null:
		return false
	var planted := SeedStatus.new()
	planted.gambit = self
	planted.owner = owner
	host.add_status(planted)
	KeepsakeVfx.virus_jump(unit.global_position, host)
	host.show_float_text("Seeded", Replicator.LIGHT)
	return true


## Hatches a seed on `host` that has grown `progress` (0..1) of the way.
func hatch(host: BattleUnit, owner: Dictionary, progress: float) -> void:
	var parent: Node = owner["parent"]
	if not is_instance_valid(parent) or profile == null:
		return
	KeepsakeVfx.missile_blast(parent, host.global_position, 44.0, Replicator.COLOR)
	for cell in Replicator.free_cells_near(host.grid, host.cell, hatch_count):
		_spawn(owner, parent, cell, lerpf(min_start_health, 1.0, progress))


func _spawn(owner: Dictionary, parent: Node, cell: Vector2i, start_share: float) -> void:
	var replicant := UNIT_SCENE.instantiate() as BattleUnit
	replicant.data = profile
	replicant.team = owner["team"]
	replicant.auto_place = false
	replicant.is_summon = true
	replicant.summon_keeps_gambit = true
	replicant._summoner_id = owner["credit"]
	replicant._summon_max_health = profile.max_health + owner["max_health"] * health_share
	for stat in Stats.Stat.values():
		var value := profile.get_base_stat(stat)
		if stat in SHARED_STATS:
			value += owner["stats"][stat] * stat_share
		replicant._summon_stats[stat] = value
	parent.add_child(replicant)
	replicant.place_at(cell)
	replicant.get_tree().call_group("battle_manager", "add_summon", replicant)
	if not is_instance_valid(replicant) or replicant.is_queued_for_deletion():
		return
	# After add_summon (start_combat sets full health and clears statuses).
	replicant.set_health(replicant.max_health * start_share)
	if virus_stacks > 0:
		replicant.add_status(ReplicantVirusStatus.new(virus_stacks))
	if replant_on_death > 0.0:
		replicant.add_status(ReplantStatus.new(self, owner))
	KeepsakeVfx.missile_blast(parent, replicant.global_position, 34.0, Replicator.COLOR)


## The ally near `from` with the lowest health that isn't a REPL\K8R (nor, if `skip` is
## given, a unit made from that profile: the REPLK4NT), preferring ones without a seed
## already. Null if there's none.
static func pick_host(unit: BattleUnit, from: Vector2i, reach: int, skip: UnitData = null) -> BattleUnit:
	var best: BattleUnit = null
	var best_seeded := true
	for node in unit.get_tree().get_nodes_in_group("units"):
		var ally := node as BattleUnit
		if ally == null or ally == unit or not ally.alive or not ally.active or ally.team != unit.team \
				or Replicator.is_replk8r(ally) or unit.grid.get_distance(from, ally.cell) > reach:
			continue
		if skip != null and ally.data == skip:
			continue
		var seeded := SeedStatus.has_seed(ally)
		if best == null or (best_seeded and not seeded) \
				or (seeded == best_seeded and ally.health < best.health):
			best = ally
			best_seeded = seeded
	return best


## A2: a REPLK4NT's attacks give Mono-Virus.
class ReplicantVirusStatus extends Status:
	var stacks: int

	func _init(p_stacks: int) -> void:
		stacks = p_stacks

	func on_attack_hit(unit: BattleUnit, target: BattleUnit, dealt: float) -> void:
		if dealt > 0.0 and target.alive:
			MonoVirusStatus.infect(target, stacks, unit.get_credit_id())


## A1: when this REPLK4NT dies, it plants a new seed nearby.
class ReplantStatus extends Status:
	var gambit: SeedGambit
	var owner: Dictionary

	func _init(p_gambit: SeedGambit, p_owner: Dictionary) -> void:
		gambit = p_gambit
		owner = p_owner

	func on_applied(unit: BattleUnit) -> void:
		unit.died.connect(_on_died)

	func on_removed(unit: BattleUnit) -> void:
		if unit.died.is_connected(_on_died):
			unit.died.disconnect(_on_died)

	func _on_died(unit: BattleUnit) -> void:
		if unit.is_inside_tree():
			gambit.plant(unit, owner, unit.cell, true)
