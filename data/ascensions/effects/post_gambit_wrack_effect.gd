class_name PostGambitWrackEffect
extends Passive
## An Ascension effect (Follow Through): after the unit casts its Gambit, its next Attacks
## attacks (the Gambit's own strikes count) gain Bonus Wrack Damage.

@export var attacks: int = 2
## 0.5 = +50% Wrack Damage.
@export var bonus: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(FollowThroughStatus.new(self))


class FollowThroughStatus extends Status:
	var effect: PostGambitWrackEffect
	var _left := 0
	var _this_attack := false   # true while the latest attack is a boosted one

	func _init(p_effect: PostGambitWrackEffect) -> void:
		effect = p_effect

	func on_gambit(_unit: BattleUnit) -> void:
		_left = effect.attacks

	# on_attack runs before the attack's damage is worked out, so it marks this attack.
	func on_attack(_unit: BattleUnit) -> void:
		_this_attack = _left > 0
		if _this_attack:
			_left -= 1

	func modify_wrack_damage(_unit: BattleUnit, _target: BattleUnit, value: float) -> float:
		return value + effect.bonus if _this_attack else value
