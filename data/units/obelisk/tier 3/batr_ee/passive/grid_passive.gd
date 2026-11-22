class_name GridPassive
extends Passive
## BATR.EE's passive (Power Grid). Allies within Range Cells of it, BATR.EE included,
## build Voltage (see VoltageStatus) at Voltage Per Second. Units keep their Voltage when
## they leave the aura; casting their Gambit clears it. While BATR.EE charges its B path
## railgun, it builds its own Voltage faster (RailgunGambit.charge_voltage_multiplier).
## Upgrades change it through GridBoostPassive:
##   A: BATR.EE gains Voltage whenever a unit in its aura casts its Gambit.
##   A1: BATR.EE's Voltage gives it Wrack Chance.

## How far allies can be from BATR.EE to build Voltage, in hex cells.
@export var range_cells: int = 2
## Voltage each unit in the aura builds per second.
@export var voltage_per_second: float = 2.0


func on_battle_start(unit: BattleUnit) -> void:
	VoltageStatus.ensure(unit)
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
	const RECHECK := 0.25   # seconds between looking for allies to listen to (A)

	var passive: GridPassive
	var _holder   # untyped: may be freed
	var _listening: Dictionary = {}   # ally instance id -> true
	var _timer := 0.0

	func _init(p_passive: GridPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_applied(unit: BattleUnit) -> void:
		_holder = unit

	## A1: Wrack Chance from BATR.EE's own Voltage.
	func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat != Stats.Stat.WRACK_CHANCE:
			return value
		var per: float = GridBoostPassive.boosts(unit)["wrack_per_voltage"]
		if per <= 0.0:
			return value
		var voltage := VoltageStatus.of(unit)
		return value + per * floorf(voltage.stacks) if voltage != null else value

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active or not unit.alive:
			return
		var boost := GridBoostPassive.boosts(unit)
		var reach: int = passive.range_cells + boost["range"]
		var listen: bool = boost["cast_voltage_share"] > 0.0
		_timer -= delta
		var relisten := listen and _timer <= 0.0
		if relisten:
			_timer = RECHECK
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally == null or not ally.alive or ally.team != unit.team:
				continue
			if relisten and ally != unit and not _listening.has(ally.get_instance_id()):
				_listening[ally.get_instance_id()] = true
				ally.gambit_cast.connect(_on_ally_cast)
			if ally.active and in_range(unit, ally, reach):
				var rate := passive.voltage_per_second
				if ally == unit:
					rate *= _charge_multiplier(unit)
				VoltageStatus.ensure(ally).add(rate * delta)

	## B: while BATR.EE is charging its railgun (casting it), its own Voltage builds faster.
	func _charge_multiplier(unit: BattleUnit) -> float:
		if unit._casting and unit.gambit is RailgunGambit:
			return unit.gambit.charge_voltage_multiplier
		return 1.0

	## A: a unit in the aura cast its Gambit: BATR.EE gains a share of its max Charge.
	func _on_ally_cast(ally: BattleUnit) -> void:
		if not is_instance_valid(_holder) or not _holder.alive or not _holder.active:
			return
		var share: float = GridBoostPassive.boosts(_holder)["cast_voltage_share"]
		var reach: int = passive.range_cells + GridBoostPassive.boosts(_holder)["range"]
		if share <= 0.0 or not in_range(_holder, ally, reach):
			return
		VoltageStatus.ensure(_holder).add(ally.max_charge * share)
		KeepsakeVfx.pulse_glow(_holder, "VfxBatreeVoltage", VoltageStatus.COLOR, 0.4)
		if KeepsakeVfx.enabled() and ally.is_inside_tree():   # a small jolt from the ally to BATR.EE
			var jolt := Volt.fire(_holder.get_parent(), ally.global_position, _holder, VoltageStatus.COLOR, 0.0, Callable())
			jolt.scale = Vector2(0.6, 0.6)

	static func in_range(unit: BattleUnit, ally: BattleUnit, reach: int) -> bool:
		return unit.grid.get_distance(unit.cell, ally.cell) <= reach
