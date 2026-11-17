class_name GambitExecuteEffect
extends Passive
## An Ascension effect (Culling Hook): the unit's Gambit damage kills outright any enemy it
## leaves at or below Health Threshold of its max health. Runs as the damage lands, so the
## Gambit sees the kill (a Rend kill counts for Codger's B1).

## 0.2 = an enemy left at 20% health or less dies.
@export var health_threshold: float = 0.2


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GambitExecuteStatus.new(self))


class GambitExecuteStatus extends Status:
	var effect: GambitExecuteEffect

	func _init(p_effect: GambitExecuteEffect) -> void:
		effect = p_effect

	func on_gambit_damage(unit: BattleUnit, target: BattleUnit, _amount: float) -> void:
		if not target.alive or target.health > target.max_health * effect.health_threshold:
			return
		# The health it had left still counts as the unit's damage on the meter.
		unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), target.health)
		target.show_float_text("Executed", ExecuteStatus.EXECUTE_COLOR)
		target.kill()
