class_name GatePassive
extends Passive
## GATE.W(A) can't move or attack. It gains Charge over time instead, for its Gambit.
## It also keeps a record of allies who die, for its B Gambit's revive (see ReviveGambit).
## Its A1 and A2 upgrades are more of these passives, with no regen of their own, that react
## to units that didn't start there (see GateRules).

## Charge per second, before Insight (which multiplies all Charge gained).
@export var charge_regen: float = 8.0
## A1: Celerity newcomer allies gain whenever GATE.W(A) casts, and for how long. 0 = none.
@export var cast_celerity: float = 0.0
@export var cast_celerity_duration: float = 5.0
## A2: Charge GATE.W(A) gains whenever a newcomer ally dies. 0 = none.
@export var charge_per_newcomer_death: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GateStatus.new(self))


## The fallen allies GATE.W(A) can revive, newest last (see ReviveGambit).
static func fallen(unit: BattleUnit) -> Array:
	for status in unit.statuses:
		if status is GateStatus and status.records_deaths:
			return status.fallen
	return []


class GateStatus extends Status:
	const RECHECK := 0.25   # seconds between looking for allies to watch

	var passive: GatePassive
	var records_deaths := false   # only the first GateStatus keeps the record
	var fallen: Array = []        # [{data, path, buffs, items, cell, army_index}], newest last
	var _holder   # untyped: may be freed
	var _watching: Dictionary = {}
	var _timer := 0.0

	func _init(p_passive: GatePassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func blocks_movement(_unit: BattleUnit) -> bool:
		return true

	func on_applied(unit: BattleUnit) -> void:
		_holder = unit
		records_deaths = not unit.statuses.any(func(s): return s is GateStatus and s != self)
		unit.gambit_cast.connect(_on_cast)

	func on_removed(unit: BattleUnit) -> void:
		if unit.gambit_cast.is_connected(_on_cast):
			unit.gambit_cast.disconnect(_on_cast)

	func tick(unit: BattleUnit, delta: float) -> void:
		unit._attack_timer = maxf(unit._attack_timer, 1.0)   # it never attacks
		if not unit.active or not unit.alive:
			return
		if passive.charge_regen > 0.0:
			unit.gain_charge(passive.charge_regen * delta)
		_timer -= delta
		if _timer > 0.0:
			return
		_timer = RECHECK
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally == null or ally == unit or ally.team != unit.team or not ally.alive:
				continue
			if not _watching.has(ally.get_instance_id()):
				_watching[ally.get_instance_id()] = true
				ally.died.connect(_on_ally_died)

	func _on_ally_died(ally: BattleUnit) -> void:
		if not is_instance_valid(_holder) or not _holder.alive or not _holder.active:
			return
		if records_deaths and not ally.is_summon and ally.data != null:
			fallen.append({
				"data": ally.data, "path": ally.upgrade_path.duplicate(), "buffs": ally.buffs,
				"items": ally.keepsakes.duplicate(), "cell": ally.cell,
				"army_index": ally.get_meta("army_index", -1),
			})
		if passive.charge_per_newcomer_death > 0.0 and GateRules.is_newcomer(ally):
			_holder.gain_charge(passive.charge_per_newcomer_death)
			KeepsakeVfx.pulse_glow(_holder, "VfxGateCharge", GateRules.COLOR, 0.4)

	## A1: every newcomer ally gets a burst of Celerity.
	func _on_cast(unit: BattleUnit) -> void:
		if passive.cast_celerity <= 0.0:
			return
		# Next frame, so the units this cast brings in get it too.
		await unit.get_tree().physics_frame
		if not is_instance_valid(unit) or not unit.is_inside_tree():
			return
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally != null and ally.alive and ally.team == unit.team and GateRules.is_newcomer(ally):
				ally.add_status(TimedStatStatus.new(Stats.Stat.CELERITY, passive.cast_celerity, passive.cast_celerity_duration))
				KeepsakeVfx.pulse_glow(ally, "VfxGateHaste", GateRules.COLOR, passive.cast_celerity_duration)
