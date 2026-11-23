class_name UnstableEffect
extends Passive
## BATR.EE's hero Ascension (its stat gains are the Ascension's own stats): after each of
## its Gambits has had its effect, it takes Self Damage of its max health as Pure Damage and
## is stunned for Stun seconds.

## 0.15 = 15% of its max health.
@export var self_damage: float = 0.15
@export var stun: float = 1.5

const COLOR := Color(0.62, 0.3, 1.0)


func on_battle_start(unit: BattleUnit) -> void:
	var status := UnstableStatus.new()
	status.effect = self
	unit.add_status(status)


class UnstableStatus extends Status:
	var effect: UnstableEffect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_finished(unit: BattleUnit) -> void:
		if not unit.alive:
			return
		KeepsakeVfx.burst(unit, UnstableEffect.COLOR)
		unit.take_damage(unit.max_health * effect.self_damage, 0, Stats.DamageType.PURE)
		if unit.alive:
			unit.stun(effect.stun)
