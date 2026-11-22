class_name GloryBoonEffect
extends Passive
## An Ascension effect (Sword Court's Glory payoffs): units in the army can gain Extra Cap
## more Glory each combat, and whenever one gains Glory it gets a Shield of Shield Share of
## its max health (for Shield Duration seconds) and/or a burst of Charge Share of its max
## Charge. Army units only.

@export var extra_cap: int = 1
@export_range(0.0, 1.0, 0.05) var shield_share: float = 0.0
@export var shield_duration: float = 4.0
@export_range(0.0, 1.0, 0.05) var charge_share: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	if unit.is_summon:
		return
	unit.add_status(BoonStatus.new(self))


class BoonStatus extends Status:
	var effect: GloryBoonEffect

	func _init(p_effect: GloryBoonEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_glory_cap(_unit: BattleUnit, cap: int) -> int:
		return cap + effect.extra_cap

	func on_glory_gained(unit: BattleUnit) -> void:
		if effect.shield_share > 0.0:
			unit.add_shield(unit.max_health * effect.shield_share, effect.shield_duration, unit.get_instance_id())
		if effect.charge_share > 0.0 and unit.gambit != null and unit.alive:
			# A burst, like a refund: it lands even while something blocks Charge gain.
			unit.charge = minf(unit.charge + unit.max_charge * effect.charge_share, unit.max_charge)
			unit._update_charge_bar()
