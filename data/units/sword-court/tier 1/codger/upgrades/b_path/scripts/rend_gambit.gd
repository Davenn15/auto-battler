class_name RendGambit
extends Gambit
## Codger B: rends his target with his bladehook for Damage + Might Scaling x Might, and
## gives it Bleed for Bleed Damage + Bleed Might Scaling x Might (see Bleed).
##   B1: if the target dies to the hit, or at any point while it's Bleeding (from anyone),
##       Codger gains a stack of Glory (base attributes and Wards +5% for the rest of the match).
##   B2: shields and healing on the target are Heal Cut less effective while it's Bleeding.

@export var damage: float = 120.0
@export var might_scaling: float = 1.0
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
@export var bleed_damage: float = 80.0
@export var bleed_might_scaling: float = 0.8
## B1: 1 = the target dying to the hit or while Bleeding gives Codger a stack of Glory.
@export var glory_on_kill: float = 0.0
## B2: share taken off shields and healing on the target while it's Bleeding (0.4 = 40% less).
@export var heal_cut: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	return _pick_target(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var target := _pick_target(caster)
	if target == null:
		BladehookGambit.refund(caster)   # its target died or left reach during the wind-up
		return
	CodgerFx.rend(caster.get_parent(), caster.global_position, target.global_position)
	# Bleed (and B1/B2's mark) go on first, so a kill by the hit itself counts for B1.
	var might := caster.get_stat(Stats.Stat.MIGHT)
	Bleed.apply(target, Stats.scaled(bleed_damage, bleed_might_scaling, might), caster)
	if glory_on_kill > 0.0 or heal_cut > 0.0:
		RendMark.apply(target, caster, self)
	var hit := Stats.scaled(damage, might_scaling, might)
	var wrack := caster.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit *= caster.effect_wrack_multiplier(wrack, Stats.EffectKind.GAMBIT_DAMAGE)
	var dealt := target.take_damage(BattleUnit.damage_bonus(caster, target, hit), wrack, damage_type)
	BattleUnit.gambit_damage_dealt(caster, target, dealt)
	caster.get_tree().call_group("damage_tracker", "record_damage", caster.get_instance_id(), dealt)


## His target if it's in attack range, otherwise the nearest enemy in attack range.
func _pick_target(caster: BattleUnit) -> BattleUnit:
	if caster._is_valid_target(caster.target) 			and caster.grid.get_distance(caster.cell, caster.target.cell) <= caster.attack_range:
		return caster.target
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not caster._is_valid_target(enemy):
			continue
		var distance := caster.grid.get_distance(caster.cell, enemy.cell)
		if distance <= caster.attack_range and (best == null or distance < caster.grid.get_distance(caster.cell, best.cell)):
			best = enemy
	return best


## On a target Codger has Rended (with B1 or B2): B1's Glory if it dies while Bleeding (from
## anyone), B2's cut to shields and healing while it's Bleeding. One per Codger per target;
## it stays for the rest of the fight and only acts while the target is Bleeding.
class RendMark extends Status:
	var codger   # untyped: may be freed
	var source_id: int
	var glory: bool
	var cut: float

	static func apply(target: BattleUnit, caster: BattleUnit, gambit: RendGambit) -> void:
		for status in target.statuses:
			if status is RendMark and status.source_id == caster.get_instance_id():
				return
		var mark := RendMark.new()
		mark.codger = caster
		mark.source_id = caster.get_instance_id()
		mark.glory = gambit.glory_on_kill > 0.0
		mark.cut = gambit.heal_cut
		target.add_status(mark)

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_applied(unit: BattleUnit) -> void:
		if glory:
			unit.died.connect(_on_died)

	func on_removed(unit: BattleUnit) -> void:
		if unit.died.is_connected(_on_died):
			unit.died.disconnect(_on_died)

	func _on_died(unit: BattleUnit) -> void:
		if Bleed.is_bleeding(unit) and is_instance_valid(codger) and codger.alive:
			codger.gain_glory()

	func modify_healing_received(unit: BattleUnit, amount: float) -> float:
		return amount * (1.0 - cut) if Bleed.is_bleeding(unit) else amount

	func modify_shield_received(unit: BattleUnit, amount: float) -> float:
		return amount * (1.0 - cut) if Bleed.is_bleeding(unit) else amount
