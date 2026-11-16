class_name GambitStunEffect
extends Passive
## An Ascension effect (Aftershock): the unit's Gambit damage stuns enemies for Duration
## seconds, at most once every Cooldown seconds for each enemy (so lingering Gambit damage,
## like a lava pool or Tectonic Stance's waves, can't keep them locked).

@export var duration: float = 1.0
@export var cooldown: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(GambitStunStatus.new(self))


class GambitStunStatus extends Status:
	var effect: GambitStunEffect
	var _clock := 0.0
	var _ready_at := {}   # enemy instance id -> when it can be stunned by this again

	func _init(p_effect: GambitStunEffect) -> void:
		effect = p_effect

	func tick(_unit: BattleUnit, delta: float) -> void:
		_clock += delta

	func on_gambit_damage(unit: BattleUnit, target: BattleUnit, _amount: float) -> void:
		if not target.alive:
			return
		var id := target.get_instance_id()
		if _clock < _ready_at.get(id, 0.0):
			return
		_ready_at[id] = _clock + effect.cooldown
		target.stun(effect.duration, unit)
