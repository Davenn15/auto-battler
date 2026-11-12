class_name SlimBleedPassive
extends Passive
## Slim Gateling: its attacks leave a bleed (a share of the target's max health per second,
## skipping wards; see BleedStatus).

@export var percent: float = 0.01
@export var duration: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(SlimBleedStatus.new(percent, duration))


class SlimBleedStatus extends Status:
	var percent: float
	var duration: float

	func _init(p_percent: float, p_duration: float) -> void:
		percent = p_percent
		duration = p_duration

	func get_hit_effect(unit: BattleUnit) -> HitEffect:
		return BleedHitEffect.new(unit.get_credit_id(), percent, duration)
