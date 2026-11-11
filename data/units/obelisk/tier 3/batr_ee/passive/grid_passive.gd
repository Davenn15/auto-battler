class_name GridPassive
extends Passive
## BATR.EE's passive. It can't move. Allies in range (its side of the battlefield) gain
## Charge over time, and whenever one of them casts its Gambit, BATR.EE gains Voltage
## equal to that ally's max Charge.
## Upgrades change it through GridBoostPassive:
##   A1: the range covers the whole battlefield.
##   B: while BATR.EE is Phased it gains Voltage every second.

## Charge per second allies in range gain.
@export var ally_charge_regen: float = 2.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(VoltageStatus.new())
	unit.add_status(GridStatus.new(self))


class GridStatus extends Status:
	const RECHECK := 0.25   # seconds between looking for allies to listen to

	var passive: GridPassive
	var _holder   # untyped: may be freed
	var _listening: Dictionary = {}   # ally instance id -> true
	var _timer := 0.0

	func _init(p_passive: GridPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func blocks_movement(_unit: BattleUnit) -> bool:
		return true

	func on_applied(unit: BattleUnit) -> void:
		_holder = unit

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active or not unit.alive:
			return
		var boost := GridBoostPassive.boosts(unit)
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
			if ally.active and in_range(unit, ally, boost["whole_board"]):
				ally.gain_charge(passive.ally_charge_regen * delta)
		if boost["phased_voltage"] > 0.0 and PhaseGambit.is_phased(unit):
			var voltage := VoltageStatus.of(unit)
			if voltage != null:
				voltage.add(boost["phased_voltage"] * delta)

	func _on_ally_cast(ally: BattleUnit) -> void:
		if not is_instance_valid(_holder) or not _holder.alive or not _holder.active:
			return
		if not in_range(_holder, ally, GridBoostPassive.boosts(_holder)["whole_board"]):
			return
		var voltage := VoltageStatus.of(_holder)
		if voltage != null:
			voltage.add(ally.max_charge)
			KeepsakeVfx.pulse_glow(_holder, "VfxBatreeVoltage", VoltageStatus.COLOR, 0.4)

	## On BATR.EE's side of the battlefield (anywhere, with A1).
	static func in_range(unit: BattleUnit, ally: BattleUnit, whole_board: bool) -> bool:
		if whole_board:
			return true
		return RandomTeams.half_cells(unit.grid, unit.team).has(ally.cell)
