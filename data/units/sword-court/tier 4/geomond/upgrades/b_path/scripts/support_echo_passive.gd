class_name SupportEchoPassive
extends Passive
## Geomond B2: whenever an ally within Range Cells gains a Shield or Wards during combat, he
## gains Share of it too, for Duration seconds. Copies never copy again (two Geomonds can't
## echo each other forever), and his own Shields and Wards aren't copied.

@export var share: float = 0.5
@export var duration: float = 4.0
@export var range_cells: int = 3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(EchoStatus.new(self))


class EchoStatus extends Status:
	const RECHECK := 0.25   # seconds between looking for allies to listen to
	const WARDS := [Stats.Stat.MIGHT_WARD, Stats.Stat.INSIGHT_WARD, Stats.Stat.CELERITY_WARD]
	## True while a copy is being added, so it doesn't set off any copying itself.
	static var _echoing := false

	var passive: SupportEchoPassive
	var _holder   # untyped: may be freed
	var _listening: Dictionary = {}
	var _timer := 0.0

	func _init(p_passive: SupportEchoPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_applied(unit: BattleUnit) -> void:
		_holder = unit

	func tick(unit: BattleUnit, delta: float) -> void:
		_timer -= delta
		if _timer > 0.0:
			return
		_timer = RECHECK
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally == null or ally == unit or ally.team != unit.team or not ally.alive:
				continue
			if not _listening.has(ally.get_instance_id()):
				_listening[ally.get_instance_id()] = true
				ally.status_added.connect(_on_ally_status)

	func _on_ally_status(ally: BattleUnit, status: Status) -> void:
		if EchoStatus._echoing or not is_instance_valid(_holder) or not _holder.alive or not _holder.active:
			return
		if not is_instance_valid(ally) or ally.grid == null \
				or ally.grid.get_distance(ally.cell, _holder.cell) > passive.range_cells:
			return
		var copied := false
		EchoStatus._echoing = true
		if status is ShieldStatus:
			var amount: float = status.shield * passive.share
			if amount > 0.0:
				_holder.add_shield(amount, passive.duration, _holder.get_instance_id())
				copied = true
		else:
			for ward in WARDS:
				var gain: float = status.modify_stat(ally, ward, 0.0)   # what it adds to that Ward
				if gain > 0.0:
					_holder.add_status(TimedStatStatus.new(ward, gain * passive.share, passive.duration))
					copied = true
		EchoStatus._echoing = false
		if copied:
			GeomondFx.motes(ally, _holder)
