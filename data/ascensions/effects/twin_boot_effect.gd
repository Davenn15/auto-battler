class_name TwinBootEffect
extends Passive
## REPLK8R's hero Ascension: at the start of combat it becomes two units. Each has Share of
## its max health, health and stats (its attributes and wards) and all of its Keepsakes;
## the second is a copy beside it that keeps its upgrades and Gambit. Copies (summons) never
## split again.

const UNIT_SCENE := preload("res://scenes/battle_unit.tscn")

@export var share: float = 0.6


func on_battle_start(unit: BattleUnit) -> void:
	if unit.is_summon:
		return
	var status := SplitStatus.new()
	status.share = share
	unit.add_status(status)


class SplitStatus extends Status:
	var share: float
	var done := false

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	## On its first tick in combat, once everyone is placed.
	func tick(unit: BattleUnit, _delta: float) -> void:
		if done or not unit.active or not unit.alive:
			return
		done = true
		var cells := Replicator.free_cells_near(unit.grid, unit.cell, 1)
		if cells.is_empty():
			return   # no room: it stays whole
		# The original shrinks to its share; the copy is made from it at full size.
		for stat in SegDuplicatePassive.STATS:
			unit.base_stats[stat] = unit.base_stats.get(stat, 0.0) * share
		unit.resize_health(unit.max_health * share, unit.health * share)
		var copy := UNIT_SCENE.instantiate() as BattleUnit
		copy.setup_as_summon(unit, 1.0)
		copy.summon_keeps_gambit = true
		copy.upgrade_path.assign(unit.upgrade_path)
		copy.buffs = unit.buffs
		unit.get_parent().add_child(copy)
		copy.place_at(cells[0])
		unit.get_tree().call_group("battle_manager", "add_summon", copy)
		if not is_instance_valid(copy) or copy.is_queued_for_deletion():
			return
		# After add_summon (starting combat resets it).
		copy.resize_health(unit.max_health, unit.health)
		for keepsake in unit.keepsakes:
			if copy.keepsakes.size() >= copy.max_keepsakes():
				break
			copy.swap_keepsake_in_combat(keepsake)
		copy.charge = unit.charge
		copy._update_charge_bar()
		KeepsakeVfx.missile_blast(unit.get_parent(), copy.global_position, 34.0, Replicator.COLOR)
		unit.show_float_text("Twin Boot", Replicator.LIGHT)
