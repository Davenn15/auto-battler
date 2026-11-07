class_name WrackPermissionEffect
extends Passive
## Lets one kind of the unit's effects wrack: Gambit damage, control and debuff effects,
## or heals and shields.

@export var kind: Stats.EffectKind = Stats.EffectKind.GAMBIT_DAMAGE
## Extra wrack damage for Gambit damage that could already wrack on its own.
@export var gambit_bonus: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Permit.new(self))


class Permit extends Status:
	var effect: WrackPermissionEffect

	func _init(p_effect: WrackPermissionEffect) -> void:
		effect = p_effect

	func lets_wrack(_unit: BattleUnit, kind: Stats.EffectKind) -> bool:
		return kind == effect.kind

	func gambit_wrack_bonus(_unit: BattleUnit) -> float:
		return effect.gambit_bonus
