class_name LowHealthTriggerEffect
extends Passive
## The first time each combat the unit drops below a share of its health, something
## happens: a shield, a burst of Vampirism, and/or a stun with untargetability.

@export_range(0.0, 1.0, 0.05) var threshold: float = 0.3
## Shield gained, as a share of max health. 0 = none.
@export var shield_share: float = 0.0
## Vampirism gained, and for how long. 0 = none.
@export var vampirism: float = 0.0
@export var vampirism_duration: float = 5.0
## Seconds the unit is stunned and untargetable. 0 = neither.
@export var hide_time: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Watch.new(self))


class Watch extends Status:
	var effect: LowHealthTriggerEffect
	var fired := false

	func _init(p_effect: LowHealthTriggerEffect) -> void:
		effect = p_effect

	func tick(unit: BattleUnit, _delta: float) -> void:
		if fired or not unit.active or unit.health >= unit.max_health * effect.threshold:
			return
		fired = true
		if effect.shield_share > 0.0:
			unit.add_shield(unit.max_health * effect.shield_share, effect.vampirism_duration, unit.get_instance_id())
		if effect.vampirism > 0.0:
			unit.add_status(TimedStatStatus.new(Stats.Stat.VAMPIRISM, effect.vampirism, effect.vampirism_duration))
			KeepsakeVfx.pulse_glow(unit, "VfxLastChance", KeepsakeVfx.LAST_CHANCE_GLOW, effect.vampirism_duration)
		if effect.hide_time > 0.0:
			unit.stun(effect.hide_time)
			unit.add_status(UntargetableStatus.new(effect.hide_time))
			KeepsakeVfx.phase_tint(unit, effect.hide_time)
