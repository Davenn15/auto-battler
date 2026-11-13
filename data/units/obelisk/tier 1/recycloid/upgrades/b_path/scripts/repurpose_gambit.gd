class_name RepurposeGambit
extends Gambit
## Recycloid brings back a copy of the last ally that died (not summons), with a share of
## its max health. The copy is a full copy (upgrades, items, Gambit) but counts as a summon:
## it doesn't count toward surviving Aura, and its damage is credited to Recycloid. It takes
## ramping damage every second until it dies (see RevivedStatus), and Recycloid gains no
## Charge while it's alive. Each death can only be brought back once.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn

## Share of max health the copy comes back with (0.4 = 40%).
@export var health_fraction: float = 0.4
## Damage it takes per second at first, as a share of its max health (0.02 = 2%)...
@export var decay_start: float = 0.02
## ...growing by this much more every second.
@export var decay_ramp: float = 0.02
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
	caster.get_tree().call_group("battle_manager", "add_summon", copy)
	# After add_summon: start_combat clears statuses.
	copy.set_health(copy.max_health * health_fraction)
	copy.add_status(RevivedStatus.new(decay_start, decay_ramp, celerity_bonus))
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


## On a revived copy: ramping damage every second (its only timer), and B2's Celerity.
class RevivedStatus extends Status:
	var start: float
	var ramp: float
	var celerity_bonus: float
	var _time := 0.0

	func _init(p_start: float, p_ramp: float, p_celerity: float) -> void:
		start = p_start
		ramp = p_ramp
		celerity_bonus = p_celerity

	func on_applied(unit: BattleUnit) -> void:
		if unit.sprite != null:
			unit.modulate = Color(0.75, 1.0, 0.75)   # a sickly green: it's borrowed time

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + celerity_bonus if stat == Stats.Stat.CELERITY else value

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active:
			return
		_time += delta
		unit.add_running_damage("self_burn", unit.take_warded_damage(unit.max_health * (start + ramp * _time) * delta), Color(0.75, 0.9, 0.6))


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
