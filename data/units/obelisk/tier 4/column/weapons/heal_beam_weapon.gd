class_name ColumnHealBeamWeapon
extends ColumnWeapon
## B: a continuous healing beam at the ally in range with the lowest share of its health
## (not COLUMN itself). Over one Interval it heals Heal + Insight Scaling x Insight.

@export var heal: float = 20.0
@export var insight_scaling: float = 0.2


func make_status() -> Status:
	return HealBeamStatus.new(self)


class HealBeamStatus extends Status:
	var weapon: ColumnHealBeamWeapon
	var _visual: BeamStatus.BeamLine = null

	func _init(p_weapon: ColumnHealBeamWeapon) -> void:
		weapon = p_weapon

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_removed(_unit: BattleUnit) -> void:
		if is_instance_valid(_visual):
			_visual.queue_free()

	func tick(unit: BattleUnit, delta: float) -> void:
		var ally: BattleUnit = null
		if ColumnWeapon.can_act(unit):
			ally = ColumnWeapon.lowest_ally(unit, unit.attack_range, true)
		ColumnBeamWeapon.show_beam(self, unit, ally, true, ColumnWeapon.LIGHT)
		if ally == null:
			return
		var per_interval := Stats.scaled(weapon.heal, weapon.insight_scaling, unit.get_stat(Stats.Stat.INSIGHT))
		ally.heal(per_interval * delta / (weapon.interval * ColumnWeapon.speed_scale(unit)), unit.get_instance_id(), false)
