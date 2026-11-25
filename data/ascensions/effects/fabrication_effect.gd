class_name FabricationEffect
extends Passive
## An Ascension effect (Obelisk, Fabrication): units holding at least one Keepsake at the
## start of combat gain Health and Insight. (The Keepsake it gives is the Ascension's.)

@export var health: float = 100.0
@export var insight: float = 10.0


func on_battle_start(unit: BattleUnit) -> void:
	if unit.keepsakes.is_empty():
		return
	if health > 0.0:
		unit.resize_health(unit.max_health + health, unit.health + health)
	unit.add_status(FabricationStatus.new(self))


class FabricationStatus extends Status:
	var effect: FabricationEffect

	func _init(p_effect: FabricationEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		return value + effect.insight if stat == Stats.Stat.INSIGHT else value
