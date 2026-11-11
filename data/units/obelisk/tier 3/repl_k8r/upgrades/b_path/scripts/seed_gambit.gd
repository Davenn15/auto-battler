class_name SeedGambit
extends Gambit
## REPL\K8R B (Infectious): plants a replication seed in the nearby ally (not a REPL\K8R)
## with the lowest health. The seed hatches after Gestation seconds, or sooner if that ally
## dies, and duplicates of REPL\K8R spawn next to it. The longer it gestates, the more
## health they start with (up to Max Health Share of REPL\K8R's full max health).

## How close the ally must be, in hex cells.
@export var range_cells: int = 3
## Seconds until the seed hatches on its own.
@export var gestation: float = 8.0
## Duplicates that hatch from each seed.
@export var hatch_count: int = 2
## Each duplicate's health, as a share of REPL\K8R's full max health: Min if it hatches
## at once, rising to Max at full gestation.
@export_range(0.0, 1.0, 0.01) var min_health_share: float = 0.15
@export_range(0.0, 1.0, 0.01) var max_health_share: float = 0.5


func can_use(caster: BattleUnit) -> bool:
	return pick_host(caster, caster.cell, range_cells) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	plant(caster, caster.cell)


## Plants a seed from `unit` (REPL\K8R or a duplicate, maybe dying) in the best host near
## `from`. Returns false if there was nobody to plant it in.
func plant(unit: BattleUnit, from: Vector2i) -> bool:
	var host := pick_host(unit, from, range_cells)
	if host == null:
		return false
	var planted := SeedStatus.new()
	planted.tmpl = Replicator.template(unit)
	planted.gestation = gestation
	planted.hatch_count = hatch_count
	planted.min_share = min_health_share
	planted.max_share = max_health_share
	host.add_status(planted)
	KeepsakeVfx.virus_jump(unit.global_position, host)
	host.show_float_text("Seeded", Replicator.LIGHT)
	return true


## The ally near `from` with the lowest health that isn't a REPL\K8R, preferring ones
## without a seed already. Null if there's none.
static func pick_host(unit: BattleUnit, from: Vector2i, reach: int) -> BattleUnit:
	var best: BattleUnit = null
	var best_seeded := true
	for node in unit.get_tree().get_nodes_in_group("units"):
		var ally := node as BattleUnit
		if ally == null or ally == unit or not ally.alive or ally.team != unit.team \
				or Replicator.is_replk8r(ally) or unit.grid.get_distance(from, ally.cell) > reach:
			continue
		var seeded := SeedStatus.has_seed(ally)
		if best == null or (best_seeded and not seeded) \
				or (seeded == best_seeded and ally.health < best.health):
			best = ally
			best_seeded = seeded
	return best
