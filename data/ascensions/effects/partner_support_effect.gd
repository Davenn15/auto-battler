class_name PartnerSupportEffect
extends Passive
## An Ascension effect (Partners in Crime) for a pair fighting together: when the Shielder
## casts its Gambit it shields the Partner, and when the Partner gets a kill (with an attack
## or its Gambit damage) it gives the Shielder a burst of Charge.

@export var shielder: UnitData     # Sumpton
@export var partner: UnitData      # Von Carrow
@export var shield: float = 300.0
@export var shield_duration: float = 4.0
@export var charge_on_kill: float = 30.0


func on_battle_start(unit: BattleUnit) -> void:
	if unit.data == shielder:
		unit.add_status(ShielderStatus.new(self))
	elif unit.data == partner:
		unit.add_status(PartnerStatus.new(self))


## The living, non-summon ally of `unit` made from `data`, or null.
static func ally_of(unit: BattleUnit, data: UnitData) -> BattleUnit:
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other != null and other != unit and other.alive and other.team == unit.team \
				and not other.is_summon and other.data == data:
			return other
	return null


## On the Shielder: each Gambit cast shields the Partner.
class ShielderStatus extends Status:
	var effect: PartnerSupportEffect

	func _init(p_effect: PartnerSupportEffect) -> void:
		effect = p_effect

	func on_applied(unit: BattleUnit) -> void:
		if not unit.gambit_cast.is_connected(_on_cast):
			unit.gambit_cast.connect(_on_cast)

	func on_removed(unit: BattleUnit) -> void:
		if is_instance_valid(unit) and unit.gambit_cast.is_connected(_on_cast):
			unit.gambit_cast.disconnect(_on_cast)

	func _on_cast(unit: BattleUnit) -> void:
		var partner := PartnerSupportEffect.ally_of(unit, effect.partner)
		if partner != null:
			partner.add_shield(effect.shield, effect.shield_duration, unit.get_instance_id())


## On the Partner: each kill gives the Shielder Charge.
class PartnerStatus extends Status:
	var effect: PartnerSupportEffect
	var _counted := {}   # victims already counted, so a kill never pays twice

	func _init(p_effect: PartnerSupportEffect) -> void:
		effect = p_effect

	func on_kill(unit: BattleUnit, victim: BattleUnit) -> void:
		_reward(unit, victim)

	func on_gambit_damage(unit: BattleUnit, target: BattleUnit, _amount: float) -> void:
		if not target.alive:
			_reward(unit, target)

	func _reward(unit: BattleUnit, victim: BattleUnit) -> void:
		var id := victim.get_instance_id()
		if _counted.has(id):
			return
		_counted[id] = true
		var shielder := PartnerSupportEffect.ally_of(unit, effect.shielder)
		if shielder == null:
			return
		shielder.charge = minf(shielder.charge + effect.charge_on_kill, shielder.max_charge)
		shielder._update_charge_bar()
		shielder.show_float_text("+%d Charge" % roundi(effect.charge_on_kill), BattleUnit.CHARGE_COLOR)
