class_name MendPulseEffect
extends Passive
## M-PATH's hero Ascension: his passive turns Mend Share of the damage he takes into
## delayed healing (instead of 15%), and every Pulse Interval seconds he heals allies within
## Pulse Cells for Pulse Share of all the healing he received in that time.

@export var mend_share: float = 0.3
@export var pulse_interval: float = 3.0
@export var pulse_cells: int = 2
## 0.5 = allies get half of what he was healed for.
@export var pulse_share: float = 0.5

const COLOR := Color(0.55, 1.0, 0.75)


func on_battle_start(unit: BattleUnit) -> void:
	var status := PulseStatus.new()
	status.effect = self
	unit.add_status(status)


class PulseStatus extends Status:
	var effect: MendPulseEffect
	var _received := 0.0
	var _until_pulse := 0.0
	var _share_set := false

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_applied(_unit: BattleUnit) -> void:
		_until_pulse = effect.pulse_interval

	func on_healed(_unit: BattleUnit, gained: float) -> void:
		_received += gained

	func tick(unit: BattleUnit, delta: float) -> void:
		if not _share_set:   # his passive may be added after this, so set it on the first tick
			_share_set = true
			for status in unit.statuses:
				if status is DelayedMendPassive.MendStatus:
					status.share = effect.mend_share
		if not unit.active or not unit.alive:
			return
		_until_pulse -= delta
		if _until_pulse > 0.0:
			return
		_until_pulse += effect.pulse_interval
		var amount := _received * effect.pulse_share
		_received = 0.0
		if amount <= 0.0:
			return
		var healed_any := false
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally == null or ally == unit or not ally.alive or ally.team != unit.team:
				continue
			if unit.grid.get_distance(unit.cell, ally.cell) > effect.pulse_cells:
				continue
			ally.heal(amount, unit.get_instance_id(), false)
			healed_any = true
		if healed_any:
			KeepsakeVfx.burst(unit, MendPulseEffect.COLOR)
