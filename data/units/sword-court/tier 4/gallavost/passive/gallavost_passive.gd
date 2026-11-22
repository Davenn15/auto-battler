class_name GallavostPassive
extends Passive
## At the start of combat, a share of the unit's max health turns into a shield that never
## expires: the unit starts missing that much health, with the shield making up for it.
## While the unit has no shield, each hit it deals also deals Pure Bonus of its damage as
## extra Pure Damage (see PurityStatus).

## Share of max health turned into shield (0.5 = starts at half health with a shield
## worth the other half).
@export_range(0.0, 1.0, 0.05) var shield_share: float = 0.5
## Share of each hit dealt again as Pure Damage while unshielded (0.4 = +40%).
@export_range(0.0, 2.0, 0.05) var pure_bonus: float = 0.4


func on_battle_start(unit: BattleUnit) -> void:
	var amount := unit.max_health * shield_share
	unit.set_health(unit.health - amount)
	unit.add_shield(amount, INF, unit.get_instance_id())
	var purity := PurityStatus.new()
	purity.starting_shield = amount
	purity.pure_bonus = pure_bonus
	unit.add_status(purity)
