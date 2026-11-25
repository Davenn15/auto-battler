class_name DuplicateGambit
extends Gambit
## Replicator B (Exponential) duplicates itself: Health Share of its current and max health is split evenly
## between it and its duplicates, and its keepsakes are shared out at random between them.
## Duplicates have Charge and can cast this too.
##   Share Keepsakes (on in its .tres): every duplicate gets all of its keepsakes.
##   B1: one more duplicate.

## How many Replicators there are after the split, counting itself (2 = one duplicate).
@export var copies: int = 2
## How much of its current and max health is shared out between it and its duplicates,
## evenly (1.2 = 120%: two copies get 60% each). Upgrades can raise it.
@export var health_share: float = 1.2
## 1 = every duplicate gets all of its keepsakes; 0 = they're split at random.
@export_range(0, 1) var share_keepsakes: int = 0
## Max Charge every Replicator on the team gains each time any of them casts this (see
## _raise_cost). 0 = no rising cost.
@export var charge_per_cast: float = 15.0
## Meta key on each Replicator: how many times its team has cast Replicate this combat.
const CASTS_META := "repl_casts"


## Only casts if there's room nearby for at least one duplicate.
func can_use(caster: BattleUnit) -> bool:
	return not Replicator.free_cells_near(caster.grid, caster.cell, 1).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var cells := Replicator.free_cells_near(caster.grid, caster.cell, copies - 1)
	if cells.is_empty():
		return
	var total := cells.size() + 1
	# Health Share of its health is shared out evenly: above 1, splitting gains health overall.
	var new_max := caster.max_health * health_share / total
	var new_hp := caster.health * health_share / total

	# Who gets which keepsake: index 0 is Replicator itself.
	var shares: Array = []
	for i in total:
		shares.append([])
	if share_keepsakes > 0:
		for i in range(1, total):
			shares[i] = caster.keepsakes.duplicate()
	else:
		var pool: Array = caster.keepsakes.duplicate()
		var order: Array = range(total)
		var next := CombatRng.randi_range(0, total - 1)   # who gets the first one
		while not pool.is_empty():
			var item = CombatRng.pick(pool)
			pool.erase(item)
			shares[order[next]].append(item)
			next = (next + 1) % total
		for item in caster.keepsakes.duplicate():
			if not shares[0].has(item):
				caster.swap_keepsake_in_combat(null, item)
			else:
				shares[0].erase(item)   # each copy of an item only once
		# shares[0] was emptied above; it isn't needed any more.

	var tmpl := Replicator.template(caster)
	caster.resize_health(new_max, new_hp)
	KeepsakeVfx.missile_blast(caster.get_parent(), caster.global_position, 40.0, Replicator.COLOR)
	caster.show_float_text("Replicate", Replicator.LIGHT)
	for i in cells.size():
		var copy := Replicator.spawn(tmpl, cells[i], shares[i + 1], new_max, new_hp)
		if copy != null:   # copies start at the team's raised cost (the cast already raised it)
			_apply_cost(copy, _team_casts(caster), charge_per_cast, false)


## A safety measure: every cast (the moment Charge is spent, not when it plays) makes
## Replicate cost more for every Replicator on the team, so splitting can't run away. Each
## cast so far adds Charge Per Cast to their max Charge, for the rest of combat; the new
## copies start at the raised cost (see _apply_cost).
func on_cast(caster: BattleUnit) -> void:
	_raise_cost(caster)


## How many times `caster`'s team has cast Replicate so far.
static func _team_casts(caster: BattleUnit) -> int:
	return int(caster.get_meta(CASTS_META, 0))


func _raise_cost(caster: BattleUnit) -> void:
	var team: Array[BattleUnit] = []
	var casts := 0
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team == caster.team and Replicator.is_replk8r(unit):
			team.append(unit)
			casts = maxi(casts, int(unit.get_meta(CASTS_META, 0)))
	casts += 1
	for unit in team:
		_apply_cost(unit, casts, charge_per_cast, true)


## Sets `unit`'s max Charge for `casts` Replicate casts so far (its bar shows the new size),
## with a "+Max Charge" pop and a pulse when `show` and it went up.
static func _apply_cost(unit: BattleUnit, casts: int, per_cast: float, show: bool) -> void:
	var before := unit.max_charge
	unit.set_meta(CASTS_META, casts)
	unit.set_max_charge(unit.data.max_charge + per_cast * casts)
	unit.charge = minf(unit.charge, unit.max_charge)
	unit._update_charge_bar()
	if show and unit.max_charge > before:
		unit.show_float_text("+%d Max Charge" % roundi(unit.max_charge - before), Replicator.LIGHT)
		KeepsakeVfx.pulse_glow(unit, "VfxReplCost", Replicator.COLOR, 0.5)
