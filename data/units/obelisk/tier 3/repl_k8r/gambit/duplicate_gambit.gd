class_name DuplicateGambit
extends Gambit
## REPL\K8R duplicates itself: its current health and max health are split evenly between
## it and its duplicates, and its keepsakes are shared out at random between them.
## Duplicates have Charge and can cast this too.
##   A (Exponential): every duplicate gets all of its keepsakes instead.
##   A1: one more duplicate.

## How many REPL\K8Rs there are after the split, counting itself (2 = one duplicate).
@export var copies: int = 2
## A: 1 = every duplicate gets all of its keepsakes; 0 = they're split at random.
@export_range(0, 1) var share_keepsakes: int = 0


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
	var new_max := caster.max_health / total
	var new_hp := caster.health / total

	# Who gets which keepsake: index 0 is REPL\K8R itself.
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
		Replicator.spawn(tmpl, cells[i], shares[i + 1], new_max, new_hp)
