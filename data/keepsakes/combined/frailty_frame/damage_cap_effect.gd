class_name DamageCapEffect
extends Passive
## No single instance of damage can take more than a share of the unit's max health.

@export_range(0.0, 1.0, 0.05) var cap: float = 0.25


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Frame.new(cap))


class Frame extends Status:
	var cap: float

	func _init(p_cap: float) -> void:
		cap = p_cap

	func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
		var most := unit.max_health * cap
		if damage > most:
			KeepsakeVfx.pop_icon(unit, "💪")
		return minf(damage, most)
