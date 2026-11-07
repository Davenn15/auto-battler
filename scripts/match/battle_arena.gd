class_name BattleArena
extends RefCounted
## Fights two saved armies without a screen, for simulations: the computer opponent
## testing its plans (scenes/ai_eval.tscn) and the match simulator. `host` should be a
## node used only for this: everything under it is cleared before and after each fight.


## `bottom` stands as team 1 on its own half; `top` is team 2, mirrored onto the far half,
## the same layout as a real combat. A fight still going after `time_limit` seconds is a
## draw. Returns {winner: 1, 2 or 0 for a draw, bottom_aura, top_aura, time}: the Aura of
## each side's surviving units.
static func fight(host: Node, bottom: Array[ArmyUnit], top: Array[ArmyUnit], time_limit: float, combat_seed: int = -1) -> Dictionary:
	clear(host)
	var grid := BattleGrid.new()
	grid.show_debug = false
	host.add_child(grid)
	var manager := BattleManager.new()
	manager.auto_start = false
	manager.combat_seed = combat_seed
	host.add_child(manager)
	ArmySpawner.spawn(bottom, 1, false, host)
	ArmySpawner.spawn(top, 2, true, host)
	var tree := host.get_tree()
	await tree.physics_frame
	var state := {"over": false, "winner": 0}
	manager.battle_ended.connect(func(w):
		state["over"] = true
		state["winner"] = maxi(w, 0)
	)
	manager.start_battle()
	var elapsed := 0.0
	var steps := 0
	while not state["over"] and elapsed < time_limit:
		await tree.physics_frame
		elapsed += 1.0 / 60.0
		steps += 1
	if not state["over"]:
		for node in tree.get_nodes_in_group("units"):
			(node as BattleUnit).stop_combat()
	var result := {"winner": state["winner"], "time": elapsed,
			"bottom_aura": ArmySpawner.surviving_aura(tree, 1), "top_aura": ArmySpawner.surviving_aura(tree, 2),
			"fingerprint": fingerprint(tree, steps)}
	clear(host)
	return result


## A short code summing up how a fight ended: every unit's team, name, cell and health
## (dead units included), plus how many physics steps it took. Two computers that played
## the same fight get the same code; any difference means the fights drifted apart.
static func fingerprint(tree: SceneTree, steps: int) -> String:
	var parts := PackedStringArray([str(steps)])
	for node in tree.get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null:
			continue
		var name: String = unit.data.display_name if unit.data != null else str(unit.name)
		parts.append("%d|%s|%d,%d|%.3f" % [unit.team, name, unit.cell.x, unit.cell.y, unit.health])
	return "|".join(parts).md5_text().substr(0, 12)


static func clear(host: Node) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
