class_name HeartyAuraPassive
extends Passive
## Brogaine: allies within Radius Cells gain Regeneration equal to Ally Share of their own
## max health per second, and he gains Self Share of the total Regeneration of those allies.
## A1 (GloryAuraPassive) makes both grow with his Glory.

@export var radius_cells: int = 1
## 0.015 = allies near him regenerate 1.5% of their max health every second.
@export_range(0.0, 0.2, 0.001) var ally_share: float = 0.015
## 0.4 = he regenerates 40% of what the allies near him regenerate, added up.
@export_range(0.0, 2.0, 0.05) var self_share: float = 0.4

## Set while a Brogaine adds up his allies' Regeneration, so two Brogaines side by side
## don't count each other's share forever.
static var _summing := false


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(AuraStatus.new(self))


## How much A1 grows the aura and share by: +Per Glory for every Glory he has (earlier
## fights and this one).
static func glory_boost(unit) -> float:
	if not is_instance_valid(unit):
		return 1.0
	var per := 0.0
	for passive in unit.passives:
		if passive is GloryAuraPassive:
			per += passive.per_glory
	return 1.0 + per * (unit.glory + unit.glory_gained)


## Living allies (not `unit` itself) within `radius` cells of it.
static func allies_near(unit: BattleUnit, radius: int) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	if not unit.is_inside_tree():
		return result
	for node in unit.get_tree().get_nodes_in_group("units"):
		var ally := node as BattleUnit
		if ally != null and ally != unit and ally.alive and ally.team == unit.team \
				and unit.grid.get_distance(unit.cell, ally.cell) <= radius:
			result.append(ally)
	return result


class AuraStatus extends Status:
	const CHECK_TIME := 0.5
	var passive: HeartyAuraPassive
	var _check := 0.0

	func _init(p_passive: HeartyAuraPassive) -> void:
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_applied(unit: BattleUnit) -> void:
		BrogaineFx.aura(unit, self, passive.radius_cells)

	## Hands every ally (summons too, as they arrive) the aura's receiving end; it only
	## counts while they stand near him.
	func tick(unit: BattleUnit, delta: float) -> void:
		_check -= delta
		if _check > 0.0:
			return
		_check = CHECK_TIME
		for node in unit.get_tree().get_nodes_in_group("units"):
			var ally := node as BattleUnit
			if ally == null or ally == unit or not ally.alive or ally.team != unit.team:
				continue
			if not ally.statuses.any(func(s): return s is AuraGift and s.giver == unit):
				ally.add_status(AuraGift.new(unit, passive))

	func modify_health_regen(unit: BattleUnit, regen: float) -> float:
		if HeartyAuraPassive._summing or not unit.active:
			return regen
		HeartyAuraPassive._summing = true
		var total := 0.0
		for ally in HeartyAuraPassive.allies_near(unit, passive.radius_cells):
			total += ally.get_health_regen()
		HeartyAuraPassive._summing = false
		return regen + total * passive.self_share * HeartyAuraPassive.glory_boost(unit)


## On an ally: Regeneration while it stands within reach of the Brogaine who gave it.
class AuraGift extends Status:
	var giver   # untyped: he may be freed
	var passive: HeartyAuraPassive

	func _init(p_giver: BattleUnit, p_passive: HeartyAuraPassive) -> void:
		giver = p_giver
		passive = p_passive

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func modify_health_regen(unit: BattleUnit, regen: float) -> float:
		if not is_instance_valid(giver) or not giver.alive or not giver.active:
			return regen
		if unit.grid.get_distance(unit.cell, giver.cell) > passive.radius_cells:
			return regen
		return regen + unit.max_health * passive.ally_share * HeartyAuraPassive.glory_boost(giver)
