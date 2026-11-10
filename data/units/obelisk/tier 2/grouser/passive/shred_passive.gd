class_name ShredPassive
extends Passive
## Grouser's attacks shred wards for a while; the shreds stack.
##   Passive: each hit takes Highest Amount from the target's highest ward.
##   Snipped (A): another copy with All Amount takes some from every ward too.

@export var highest_amount: float = 4.0
@export var all_amount: float = 0.0
## Seconds each shred lasts.
@export var duration: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ShredStatus.new(self))


class ShredStatus extends Status:
	var passive: ShredPassive

	func _init(p_passive: ShredPassive) -> void:
		passive = p_passive

	func on_attack_hit(unit: BattleUnit, target: BattleUnit, _dealt: float) -> void:
		if passive.highest_amount > 0.0:
			WardShiftStatus.shred(unit, target, WardShiftStatus.highest_ward(target), passive.highest_amount, passive.duration)
		if passive.all_amount > 0.0:
			for stat in WardShiftStatus.WARDS:
				WardShiftStatus.shred(unit, target, stat, passive.all_amount, passive.duration)
