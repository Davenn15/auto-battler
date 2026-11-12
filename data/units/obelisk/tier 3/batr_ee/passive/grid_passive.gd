class_name GridPassive
extends Passive
## BATR.EE's passive. Allies within Range Cells of it gain Insight, and whenever one of
## them casts its Gambit, BATR.EE gains Voltage equal to that ally's max Charge. It holds
## at most Max Voltage, and gains extra Charge while full (see VoltageStatus).
## Upgrades change it through GridBoostPassive:
##   A: wider range and more Insight.
##   B1: a higher Voltage maximum, and Voltage every second.

## How far allies can be from BATR.EE to count, in hex cells.
@export var range_cells: int = 2
## Insight allies in range gain.
@export var insight_bonus: float = 25.0
## The most Voltage BATR.EE can hold. Anything gained past it is lost.
@export var max_voltage: float = 300.0
## Extra Charge per second BATR.EE gains while its Voltage is full.
@export var full_charge_regen: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	var boost := GridBoostPassive.boosts(unit)
	var voltage := VoltageStatus.new()
	voltage.max_stacks = max_voltage + boost["max_voltage"]
	voltage.full_charge_regen = full_charge_regen
	unit.add_status(voltage)
	unit.add_status(GridStatus.new(self))
	KeepsakeVfx.grid_aura(unit, aura_range(unit), VoltageStatus.COLOR)


## How far `unit`'s Power Grid reaches, in hex cells, with its upgrades; -1 if it has none.
## Also used to show the ring while planning.
static func aura_range(unit: BattleUnit) -> int:
	for passive in unit.passives:
		if passive is GridPassive:
			return passive.range_cells + GridBoostPassive.boosts(unit)["range"]
	return -1


class GridStatus extends Status:
	const RECHECK := 0.25   # seconds between looking for allies to listen to

	var passive: GridPassive
	var _holder   # untyped: may be freed
	var _listening: Dictionary = {}   # ally instance id -> true
	var _timer := 0.0

	func _init(p_passive: GridPassive) -> void:
		passive = p_passive

	func on_applied(unit: BattleUnit) -> void:
		_holder = unit

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active or not unit.alive:
			return
		var boost := GridBoostPassive.boosts(unit)
		var reach: int = passive.range_cells + boost["range"]
		var insight: float = passive.insight_bonus + boost["insight"]
		_timer -= delta
		var relisten := _timer <= 0.0
		if relisten:
			_timer = RECHECK
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally == null or ally == unit or not ally.alive or ally.team != unit.team:
				continue
			if relisten and not _listening.has(ally.get_instance_id()):
				_listening[ally.get_instance_id()] = true
				ally.gambit_cast.connect(_on_ally_cast)
			if ally.active and in_range(unit, ally, reach):
				GridInsightStatus.refresh_on(ally, unit.get_instance_id(), insight)
		if boost["voltage_per_second"] > 0.0:
			var voltage := VoltageStatus.of(unit)
			if voltage != null:
				voltage.add(boost["voltage_per_second"] * delta)

	func _on_ally_cast(ally: BattleUnit) -> void:
		if not is_instance_valid(_holder) or not _holder.alive or not _holder.active:
			return
		var reach: int = passive.range_cells + GridBoostPassive.boosts(_holder)["range"]
		if not in_range(_holder, ally, reach):
			return
		var voltage := VoltageStatus.of(_holder)
		if voltage != null:
			voltage.add(ally.max_charge)
			KeepsakeVfx.pulse_glow(_holder, "VfxBatreeVoltage", VoltageStatus.COLOR, 0.4)
			if KeepsakeVfx.enabled() and ally.is_inside_tree():   # a small jolt from the ally to BATR.EE
				var jolt := Volt.fire(_holder.get_parent(), ally.global_position, _holder, VoltageStatus.COLOR, 0.0, Callable())
				jolt.scale = Vector2(0.6, 0.6)

	static func in_range(unit: BattleUnit, ally: BattleUnit, reach: int) -> bool:
		return unit.grid.get_distance(unit.cell, ally.cell) <= reach


## Being near a BATR.EE: extra Insight. Refreshed every step while the ally stays in range;
## wears off a moment after it leaves or BATR.EE dies. One per BATR.EE.
class GridInsightStatus extends Status:
	const LINGER := 0.3   # seconds it lasts after its last refresh

	var source_id: int
	var amount: float
	var _left := LINGER

	static func refresh_on(ally: BattleUnit, p_source_id: int, p_amount: float) -> void:
		for status in ally.statuses:
			if status is GridInsightStatus and status.source_id == p_source_id:
				status.amount = p_amount
				status._left = LINGER
				return
		var boost := GridInsightStatus.new()
		boost.source_id = p_source_id
		boost.amount = p_amount
		ally.add_status(boost)

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + amount if stat == Stats.Stat.INSIGHT else value

	func tick(unit: BattleUnit, delta: float) -> void:
		_left -= delta
		if _left <= 0.0:
			unit.remove_status(self)
