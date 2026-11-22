class_name PurityStatus
extends Status
## While the unit has no shield, each hit it deals (attacks, Gambit hits: any direct damage)
## also deals Pure Bonus of that hit's damage as extra Pure Damage.

var starting_shield: float = 0.0   # the shield she started the battle with, for her rebuild
var rebuilt: bool = false   # she gets one rebuild per combat
var pure_bonus: float = 0.4
var _adding := false   # true while the bonus itself lands, so it doesn't add a bonus of its own


func on_direct_damage_dealt(unit: BattleUnit, target: BattleUnit, amount: float) -> void:
	if _adding or amount <= 0.0 or pure_bonus <= 0.0 or unit.get_shield() > 0.0:
		return
	if not is_instance_valid(target) or not target.alive or target.team == unit.team:
		return
	_adding = true
	var dealt := target.take_damage(amount * pure_bonus, 0, Stats.DamageType.PURE)
	unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), dealt)
	_adding = false
