class_name GambitHitEffectsEffect
extends Passive
## An Ascension effect (Arcane Edge): the unit's Gambit damage triggers its Hit Effects, at
## most once every Cooldown seconds for each enemy. See BattleUnit.gambit_damage_dealt.

## Seconds before the same enemy can trigger it again.
@export var cooldown: float = 2.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GambitHitStatus.new(cooldown))


class GambitHitStatus extends Status:
	var cooldown: float
	var _clock := 0.0
	var _ready_at := {}   # enemy instance id -> when it can trigger again

	func _init(p_cooldown: float) -> void:
		cooldown = p_cooldown

	func tick(_unit: BattleUnit, delta: float) -> void:
		_clock += delta

	func on_gambit_damage(unit: BattleUnit, target: BattleUnit, amount: float) -> void:
		var id := target.get_instance_id()
		if _clock < _ready_at.get(id, 0.0):
			return
		_ready_at[id] = _clock + cooldown
		var effects: Array[HitEffect] = []
		for status in unit.statuses.duplicate():
			if status == self:
				continue
			var effect: HitEffect = status.get_hit_effect(unit)
			if effect != null:
				effects.append(effect)
		BattleUnit.run_hit_effects(effects, target, amount, 0)
