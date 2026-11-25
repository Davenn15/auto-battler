class_name SegSwapPassive
extends Passive
## Fault A1: if Fault would die while its duplicate lives, the duplicate dies
## instead: Fault is left at 1 health, teleports to the duplicate's cell, and gains a
## shield of Shield Share of the duplicate's remaining health for Shield Duration seconds.

@export_range(0.0, 2.0, 0.05) var shield_share: float = 1.0
@export var shield_duration: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	if not unit.is_summon:
		unit.add_status(SwapStatus.new(self))


class SwapStatus extends Status:
	var passive: SegSwapPassive

	func _init(p_passive: SegSwapPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func prevents_death(unit: BattleUnit) -> bool:
		var dup := SegDuplicatePassive.duplicate_of(unit)
		if dup == null:
			return false
		var left := maxf(dup.health, 0.0)
		var cell := dup.cell
		SegFx.blink(dup.global_position, unit.get_parent())
		dup.kill()   # frees its cell
		unit.health = maxf(unit.health, 1.0)
		SegFx.blink(unit.global_position, unit.get_parent())
		if unit.grid.can_place(cell):
			unit.place_at(cell)
		unit.add_shield(left * passive.shield_share, passive.shield_duration, unit.get_instance_id())
		unit.show_float_text("Fault swap", SegFx.LIGHT)
		return true
