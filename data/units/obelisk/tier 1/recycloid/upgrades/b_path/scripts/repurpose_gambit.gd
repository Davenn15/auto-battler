class_name RepurposeGambit
extends Gambit
## Recycloid brings back a copy of the last ally that died (not summons), with a share of
## its max health. The copy is a full copy (upgrades, items, Gambit) but counts as a summon:
## it doesn't count toward surviving Aura, and its damage is credited to Recycloid. It takes
## ramping damage every second until it dies (see RevivedStatus), and Recycloid gains no
## Charge while it's alive. Each death can only be brought back once.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn

## Share of max health the copy comes back with (0.4 = 40%). It then decays (see Revive).
@export var health_fraction: float = 0.4
## B2: Celerity the copy gains. 0 = none.
@export var celerity_bonus: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	var record := _record(caster)
	return not record.is_empty() and _spawn_cell(caster, record) != NO_CELL


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var watcher := _watcher(caster)
	if watcher == null or watcher.last_dead_ally.is_empty():
		return
	var record: Dictionary = watcher.last_dead_ally
	var cell := _spawn_cell(caster, record)
	if cell == NO_CELL:
		return
	watcher.last_dead_ally = {}   # each death can only be brought back once

	var copy := UNIT_SCENE.instantiate() as BattleUnit
	copy.data = record["data"]
	copy.team = caster.team
	copy.upgrade_path.assign(record["path"])
	copy.buffs = record["buffs"]
	copy.auto_place = false
	caster.get_parent().add_child(copy)   # _ready builds it from its data
	for item in record["items"]:
		copy.equip(item)
	copy.place_at(cell)
	# Built as a normal unit (so it keeps its own stats and Gambit), then made a summon.
	copy.is_summon = true
	copy._summoner_id = caster.get_credit_id()
	Revive.mark(copy)
	caster.get_tree().call_group("battle_manager", "add_summon", copy)
	if not is_instance_valid(copy) or copy.is_queued_for_deletion():
		return
	# After add_summon: start_combat clears statuses.
	copy.add_status(RevivedStatus.new(celerity_bonus))
	Revive.start(copy, copy.max_health * health_fraction)
	caster.add_status(RevivedLinkStatus.new(copy))
	KeepsakeVfx.recycle_orb(caster.global_position, copy)
	copy.show_float_text("Repurposed", VacuumChannel.VACUUM_COLOR)


func _watcher(caster: BattleUnit) -> RecycleStatus:
	for status in caster.statuses:
		if status is RecycleStatus:
			return status
	return null


func _record(caster: BattleUnit) -> Dictionary:
	var watcher := _watcher(caster)
	return watcher.last_dead_ally if watcher != null else {}


const NO_CELL := Vector2i(-999, -999)

## Where the copy appears: where the ally died if that's free, else the nearest free cell
## to it, else the nearest free cell to Recycloid.
func _spawn_cell(caster: BattleUnit, record: Dictionary) -> Vector2i:
	var grid := caster.grid
	var death: Vector2i = record["cell"]
	for center in [death, caster.cell]:
		if grid.has_cell(center) and grid.can_place(center):
			return center
		var cells := grid.free_cells_in_range(center, 3)
		if not cells.is_empty():
			cells.sort_custom(func(a, b): return grid.get_distance(center, a) < grid.get_distance(center, b))
			return cells[0]
	return NO_CELL


## On a revived copy: B2's Celerity (the decay is Revive's).
class RevivedStatus extends Status:
	var celerity_bonus: float

	func _init(p_celerity: float) -> void:
		celerity_bonus = p_celerity

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + celerity_bonus if stat == Stats.Stat.CELERITY else value


## On Recycloid while his copy lives: no Charge for him.
class RevivedLinkStatus extends Status:
	var copy   # untyped: it may be freed

	func _init(p_copy: BattleUnit) -> void:
		copy = p_copy

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return is_instance_valid(copy) and copy.alive

	func tick(unit: BattleUnit, _delta: float) -> void:
		if not is_instance_valid(copy) or not copy.alive:
			unit.remove_status(self)
