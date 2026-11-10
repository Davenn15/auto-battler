class_name ChargeFlowPassive
extends Passive
## VE5TIBULE's A path. Each number is Charge per second; 0 = none.
##   A: he gains Charge over time.
##   A1: his allies gain Charge over time while phased.
##   A2: his enemies lose Charge over time while phased.
## "Phased" means stunned and untargetable at once (see PhaseGambit.is_phased).

@export var self_regen: float = 0.0
@export var phased_ally_regen: float = 0.0
@export var phased_enemy_decay: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ChargeFlowStatus.new(self))


class ChargeFlowStatus extends Status:
	var passive: ChargeFlowPassive

	func _init(p_passive: ChargeFlowPassive) -> void:
		passive = p_passive

	func tick(unit: BattleUnit, delta: float) -> void:
		if not unit.active:
			return
		if passive.self_regen > 0.0:
			unit.gain_charge(passive.self_regen * delta)
		if passive.phased_ally_regen <= 0.0 and passive.phased_enemy_decay <= 0.0:
			return
		for node in unit.get_tree().get_nodes_in_group("units"):
			var other := node as BattleUnit
			if other == null or not PhaseGambit.is_phased(other):
				continue
			if other.team == unit.team and passive.phased_ally_regen > 0.0:
				# Straight into the bar: being stunned would block normal Charge gain.
				other.charge = minf(other.charge + passive.phased_ally_regen * delta, other.max_charge)
				other._update_charge_bar()
			elif other.team != unit.team and passive.phased_enemy_decay > 0.0 and other.charge > 0.0:
				other.charge = maxf(other.charge - passive.phased_enemy_decay * delta, 0.0)
				other._update_charge_bar()
