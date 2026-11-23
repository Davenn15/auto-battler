class_name LastStandEffect
extends Passive
## Scour's hero Ascension: the first time each combat he would die (damage, Overdrive's
## burn, or B's Haywire detonation), he stays alive at 1 health and gains a Shield of Shield
## Share of his max health for Shield Duration seconds. Executes still kill him.

## 0.4 = a Shield of 40% of his max health.
@export var shield_share: float = 0.4
@export var shield_duration: float = 4.0

const COLOR := Color(1.0, 0.45, 0.2)


func on_battle_start(unit: BattleUnit) -> void:
	var status := SaveStatus.new()
	status.effect = self
	unit.add_status(status)


class SaveStatus extends Status:
	var effect: LastStandEffect
	var used := false

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func prevents_death(unit: BattleUnit) -> bool:
		if used:
			return false
		used = true
		unit.health = maxf(unit.health, 1.0)
		unit.add_shield(unit.max_health * effect.shield_share, effect.shield_duration, unit.get_instance_id())
		unit.show_float_text("Failsafe", LastStandEffect.COLOR)
		KeepsakeVfx.burst(unit, LastStandEffect.COLOR)
		return true
