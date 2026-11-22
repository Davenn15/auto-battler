class_name LowHealthGloryEffect
extends Passive
## An Ascension effect (Brogaine's hero Ascension): the first time each combat the unit
## drops below Health Share of its max health, it gains Glory; and it can gain Extra Cap
## more Glory each combat than usual (so that Glory doesn't crowd out its others).

@export_range(0.0, 1.0, 0.05) var health_share: float = 0.4
@export var extra_cap: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(LowHealthGloryStatus.new(self))


class LowHealthGloryStatus extends Status:
	var effect: LowHealthGloryEffect
	var _done := false

	func _init(p_effect: LowHealthGloryEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_glory_cap(_unit: BattleUnit, cap: int) -> int:
		return cap + effect.extra_cap

	func tick(unit: BattleUnit, _delta: float) -> void:
		if _done or not unit.active or not unit.alive:
			return
		if unit.health < unit.max_health * effect.health_share:
			_done = true
			unit.gain_glory()
