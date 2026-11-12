class_name GatePassive
extends Passive
## GATE.W(A) can't move or attack. Whenever it casts, every unit it brought in (its
## Gatelings, or allies it revived) is healed and permanently gains a share of its
## attributes and wards for the rest of combat (GateBoonStatus, stacking each cast).
## With A2 that goes to every summoned or revived ally instead (GateWideBoonPassive).
## It also keeps a record of allies who die, for its B Gambit's revive (see ReviveGambit).
## While it's the only living unit on its team it takes ramping damage, like Sumpton's bag.
## Its Charge comes from Charge Regen (UnitData.charge_regen plus Insight); under the old
## Insight rule there's no Charge Regen, so this passive gives Old Rule Regen instead.

## Charge per second, only under the old Insight rule (Stats.insight_charge_regen off).
@export var old_rule_regen: float = 8.0
## Share of its max health each follower is healed for on every cast (0.25 = 25%).
@export_range(0.0, 1.0, 0.05) var cast_heal_share: float = 0.25
## Attributes and wards each follower gains per cast, as a share (0.1 = +10% per cast).
@export_range(0.0, 1.0, 0.01) var cast_stat_bonus: float = 0.1
@export_group("While alone")
## Share of its max health it loses per second while it's the only living unit on its team
## (0.02 = 2%), like Sumpton's bag after Sumpton dies. Skips wards.
@export var lone_decay_start: float = 0.02
## How much that rate climbs every second it stays alone (0.02 = +2% per second, each second).
## Starts over if an ally joins it again.
@export var lone_decay_ramp: float = 0.02


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GateStatus.new(self))


## The fallen allies GATE.W(A) can revive, newest last (see ReviveGambit).
static func fallen(unit: BattleUnit) -> Array:
	for status in unit.statuses:
		if status is GateStatus:
			return status.fallen
	return []


class GateStatus extends Status:
	const RECHECK := 0.25   # seconds between looking for allies to watch

	var passive: GatePassive
	var fallen: Array = []        # [{data, path, buffs, items, cell, army_index}], newest last
	var casts_done := 0           # for GateSequenceGambit: which Gateling comes next
	var _alone_for := -1.0        # seconds it's been the only living unit on its team; -1 = not alone
	var _holder   # untyped: may be freed
	var _watching: Dictionary = {}
	var _timer := 0.0

	func _init(p_passive: GatePassive) -> void:
		passive = p_passive

	func blocks_attacks(_unit: BattleUnit) -> bool:
		return true   # it never attacks

	func blocks_movement(_unit: BattleUnit) -> bool:
		return true

	func on_applied(unit: BattleUnit) -> void:
		_holder = unit
		unit.gambit_cast.connect(_on_cast)

	func on_removed(unit: BattleUnit) -> void:
		if unit.gambit_cast.is_connected(_on_cast):
			unit.gambit_cast.disconnect(_on_cast)

	func tick(unit: BattleUnit, delta: float) -> void:
		unit._attack_timer = maxf(unit._attack_timer, 1.0)   # it never attacks
		if not unit.active or not unit.alive:
			return
		if not Stats.insight_charge_regen and passive.old_rule_regen > 0.0:
			unit.gain_charge(passive.old_rule_regen * delta)
		_lone_decay(unit, delta)
		if not unit.alive:
			return
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

	## Alone on its team, it falls apart: damage over time that grows the longer it stays
	## alone, so a lone GATE.W(A) can't stall the battle.
	func _lone_decay(unit: BattleUnit, delta: float) -> void:
		var alone := true
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally != null and ally != unit and ally.alive and ally.active and ally.team == unit.team:
				alone = false
				break
		if not alone:
			_alone_for = -1.0
			return
		if _alone_for < 0.0:
			_alone_for = 0.0
			unit.show_float_text("Collapsing", GateRules.LIGHT)
		_alone_for += delta
		var rate := passive.lone_decay_start + passive.lone_decay_ramp * _alone_for   # share of max health per second
		unit.take_warded_damage(unit.max_health * rate * delta)

	func _on_ally_died(ally: BattleUnit) -> void:
		if not is_instance_valid(_holder) or not _holder.alive or not _holder.active:
			return
		# B: a burst of Charge for every ally that dies.
		for status in _holder.statuses:
			if status is GateDeathChargePassive.Marker:
				_holder.gain_charge(status.charge)
				KeepsakeVfx.pulse_glow(_holder, "VfxGateCharge", GateRules.COLOR, 0.4)
		# Each ally can only be revived once: one this GATE.W(A) already brought back stays dead.
		if ally.get_meta(GateRules.REVIVED_META, 0) == _holder.get_instance_id():
			return
		if not ally.is_summon and ally.data != null:
			fallen.append({
				"data": ally.data, "path": ally.upgrade_path.duplicate(), "buffs": ally.buffs,
				"items": ally.keepsakes.duplicate(), "cell": ally.cell,
				"army_index": ally.get_meta("army_index", -1),
			})

	## Every cast: heal and permanently boost the units it brought in (before this cast's
	## own summons arrive, so they start fresh).
	func _on_cast(unit: BattleUnit) -> void:
		if not unit.is_inside_tree():
			return
		var wide := unit.statuses.any(func(s): return s is GateWideBoonPassive.Marker)
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally == null or ally == unit or not ally.alive or ally.team != unit.team:
				continue
			if not (GateRules.is_newcomer(ally) if wide else GateRules.is_follower(ally, unit)):
				continue
			ally.heal(ally.max_health * passive.cast_heal_share, unit.get_instance_id(), false)
			GateBoonStatus.add_to(ally, passive.cast_stat_bonus)
			KeepsakeVfx.pulse_glow(ally, "VfxGateBoon", GateRules.COLOR, 0.6)


## A follower's lasting boost from GATE.W(A)'s casts: +Bonus x stacks to its Might,
## Insight, Celerity and all three wards. One per unit; each cast adds a stack.
class GateBoonStatus extends Status:
	const STATS := [Stats.Stat.MIGHT, Stats.Stat.INSIGHT, Stats.Stat.CELERITY,
			Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]
	var bonus: float
	var stacks := 0

	static func add_to(unit: BattleUnit, p_bonus: float) -> void:
		for status in unit.statuses:
			if status is GateBoonStatus:
				status.stacks += 1
				KeepsakeVfx.gate_glow(unit, status.stacks, GateRules.COLOR)
				return
		var boon := GateBoonStatus.new()
		boon.bonus = p_bonus
		boon.stacks = 1
		unit.add_status(boon)
		KeepsakeVfx.gate_glow(unit, 1, GateRules.COLOR)

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value * (1.0 + bonus * stacks) if stat in STATS else value

	func is_permanent_stat_gain() -> bool:
		return true
