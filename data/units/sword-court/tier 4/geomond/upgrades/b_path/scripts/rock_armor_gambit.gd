class_name RockArmorGambit
extends Gambit
## Geomond B (Seismic): he shields himself in rocky armor, a Shield of
## Shield Share x his max health + Shield Insight Scaling x Insight, and gains Ward Bonus
## Might Ward and Insight Ward, for Duration seconds. While the Shield holds, he pulses
## seismic waves every Pulse Interval seconds, hitting every enemy within Pulse Radius cells
## for Pulse Damage + Pulse Insight Scaling x Insight as Might damage (Gambit damage).
##   B1: each wave hit saps Sap Per Hit Might Ward and Celerity Ward from the enemy for the
##       rest of combat, up to Sap Cap of each.

@export var duration: float = 8.0
## Shield: this share of his max health (0.25 = 25%) plus Insight Scaling x Insight.
@export var shield_share: float = 0.25
@export var shield_insight_scaling: float = 1.0
## Added to his Might Ward and Insight Ward while it lasts.
@export var ward_bonus: float = 100.0
@export var pulse_interval: float = 0.75
@export var pulse_radius: int = 2
@export var pulse_damage: float = 40.0
@export var pulse_insight_scaling: float = 0.3
## B1: Might Ward and Celerity Ward each wave hit takes away, and the most it can take from
## one enemy (each). 0 = no sap.
@export var sap_per_hit: float = 0.0
@export var sap_cap: float = 30.0


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	for status in caster.statuses.duplicate():   # a recast replaces the last armor
		if status is RockArmorStatus:
			caster.remove_status(status)
	var before := caster.statuses.duplicate()
	var amount := Stats.scaled(caster.max_health * shield_share, shield_insight_scaling, caster.get_stat(Stats.Stat.INSIGHT))
	caster.add_shield(amount, duration, caster.get_instance_id(), false, true)
	var shield: ShieldStatus = null
	for status in caster.statuses:
		if status is ShieldStatus and not before.has(status):
			shield = status
	caster.add_status(RockArmorStatus.new(self, shield))
	caster.show_float_text("Rock Armor", GeomondFx.STONE_LIGHT)


## On Geomond while the armor lasts: the Ward bonus for the whole Duration, the stone look
## and the pulses while its Shield holds.
class RockArmorStatus extends Status:
	var gambit: RockArmorGambit
	var shield: ShieldStatus
	var time_left := 0.0
	var _pulse := 0.0
	var _holding := true

	func _init(p_gambit: RockArmorGambit, p_shield: ShieldStatus) -> void:
		gambit = p_gambit
		shield = p_shield
		time_left = p_gambit.duration
		_pulse = p_gambit.pulse_interval

	func on_applied(unit: BattleUnit) -> void:
		GeomondFx.armor(unit, true)

	func on_removed(unit: BattleUnit) -> void:
		GeomondFx.armor(unit, false)

	func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat == Stats.Stat.MIGHT_WARD or stat == Stats.Stat.INSIGHT_WARD:
			return value + gambit.ward_bonus
		return value

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			unit.remove_status(self)
			return
		if not _holding:
			return
		if shield == null or shield.shield <= 0.0 or not unit.statuses.has(shield):
			_holding = false   # the Shield broke: no more pulses, the Wards stay
			GeomondFx.armor(unit, false)
			return
		_pulse -= delta
		if _pulse <= 0.0 and unit.active:
			_pulse += gambit.pulse_interval
			_wave(unit)

	func _wave(unit: BattleUnit) -> void:
		GeomondFx.quake(unit, (gambit.pulse_radius + 0.5) * unit.grid.cell_spacing())
		var hit := Stats.scaled(gambit.pulse_damage, gambit.pulse_insight_scaling, unit.get_stat(Stats.Stat.INSIGHT))
		for node in unit.get_tree().get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy == null or not enemy.alive or enemy.team == unit.team \
					or unit.grid.get_distance(unit.cell, enemy.cell) > gambit.pulse_radius:
				continue
			var level := unit.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
			var amount := hit * unit.effect_wrack_multiplier(level, Stats.EffectKind.GAMBIT_DAMAGE)
			var dealt := enemy.take_damage(BattleUnit.damage_bonus(unit, enemy, amount), level, Stats.DamageType.MIGHT, false, unit, false)
			enemy.add_running_damage("seismic", dealt, Stats.damage_color(Stats.DamageType.MIGHT, level), level)
			BattleUnit.gambit_damage_dealt(unit, enemy, dealt)
			unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), dealt)
			if dealt > 0.0 and enemy.alive and gambit.sap_per_hit > 0.0:
				SeismicSapStatus.sap(enemy, gambit.sap_per_hit, gambit.sap_cap)


## B1: Might Ward and Celerity Ward taken from an enemy for the rest of combat, up to a cap.
class SeismicSapStatus extends Status:
	var amount := 0.0

	static func sap(enemy: BattleUnit, more: float, cap: float) -> void:
		for status in enemy.statuses:
			if status is SeismicSapStatus:
				status.amount = minf(status.amount + more, cap)
				return
		var sap_status := SeismicSapStatus.new()
		sap_status.amount = minf(more, cap)
		enemy.add_status(sap_status)

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_stat(unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
		if stat == Stats.Stat.MIGHT_WARD or stat == Stats.Stat.CELERITY_WARD:
			return value - amount * unit.debuff_strength()
		return value
