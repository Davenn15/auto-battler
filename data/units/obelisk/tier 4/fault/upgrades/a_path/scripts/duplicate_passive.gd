class_name SegDuplicatePassive
extends Passive
## Fault A: the first time it casts its Gambit, it leaves a duplicate of itself in the
## cell it teleported away from (the nearest free cell to it if that's taken, or its own
## neighbourhood if it never teleported). The duplicate has Share of its max health and of
## each stat, its Keepsakes, its upgrades, and its Gambit: it gains Charge and casts like
## Fault, but never makes duplicates itself. It starts with no Charge.

const UNIT_SCENE := preload("res://scenes/battle_unit.tscn")
const STATS := [Stats.Stat.MIGHT, Stats.Stat.INSIGHT, Stats.Stat.CELERITY,
		Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]
const TINT := Color(0.9, 0.95, 1.0, 0.8)   # a touch see-through: the copy
## Seconds after the first cast to give up waiting for the teleport and duplicate anyway.
const WAIT_LIMIT := 2.5

@export_range(0.05, 1.0, 0.05) var share: float = 0.6


func on_battle_start(unit: BattleUnit) -> void:
	if not unit.is_summon:   # the duplicate never duplicates
		unit.add_status(DuplicateStatus.new(self))


## The duplicate this unit made, or null (for A1).
static func duplicate_of(unit: BattleUnit) -> BattleUnit:
	for status in unit.statuses:
		if status is DuplicateStatus and is_instance_valid(status.copy) and status.copy.alive:
			return status.copy
	return null


class DuplicateStatus extends Status:
	var passive: SegDuplicatePassive
	var done := false
	var waiting := -1.0   # seconds since the first play while waiting for the teleport
	var copy   # untyped: may be freed

	func _init(p_passive: SegDuplicatePassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_played(_unit: BattleUnit) -> void:
		if not done and waiting < 0.0:
			waiting = 0.0

	## Called by the ion Gambit right after the teleport.
	func on_seg_teleport(unit: BattleUnit, from_cell: Vector2i) -> void:
		if not done and waiting >= 0.0:
			_make(unit, from_cell)

	func tick(unit: BattleUnit, delta: float) -> void:
		if done or waiting < 0.0:
			return
		waiting += delta
		if waiting >= WAIT_LIMIT:
			_make(unit, unit.cell)   # it never teleported: next to itself instead

	func _make(unit: BattleUnit, near: Vector2i) -> void:
		done = true
		var grid := unit.grid
		var cell := near
		if not grid.can_place(cell):
			var best_d := INF
			cell = Vector2i(-999, -999)
			for radius in range(1, 6):
				for c in grid.free_cells_in_range(near, radius):
					var d := grid.cell_to_world(c).distance_to(grid.cell_to_world(near))
					if d < best_d:
						best_d = d
						cell = c
				if best_d < INF:
					break
			if cell == Vector2i(-999, -999):
				return   # no room anywhere near
		var dup := UNIT_SCENE.instantiate() as BattleUnit
		dup.setup_as_summon(unit, passive.share)
		for stat in SegDuplicatePassive.STATS:
			dup._summon_stats[stat] = dup._summon_stats.get(stat, 0.0) * passive.share
		dup.summon_keeps_gambit = true
		dup.upgrade_path.assign(unit.upgrade_path)   # its upgrades too (A2's debuff); A's passive skips summons
		unit.get_parent().add_child(dup)   # _ready runs here
		dup.place_at(cell)
		dup.modulate = SegDuplicatePassive.TINT
		SegFx.blink(dup.global_position, unit.get_parent())
		unit.get_tree().call_group("battle_manager", "add_summon", dup)
		# After add_summon: starting combat resets it, so these come later.
		for keepsake in unit.keepsakes:
			if dup.keepsakes.size() >= dup.max_keepsakes():
				break
			dup.swap_keepsake_in_combat(keepsake)
		dup.charge = 0.0
		dup._update_charge_bar()
		copy = dup
