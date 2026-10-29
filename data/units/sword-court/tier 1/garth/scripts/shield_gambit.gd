class_name ShieldGambit
extends Gambit
## Grants the caster a shield for a set time.
## Damage reduction while shielded now comes from the ShieldReductionPassive.

@export var shield_amount: float = 150.0
## Seconds the shield lasts.
@export var duration: float = 5.0


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	caster.add_status(ShieldStatus.new(shield_amount, duration))
	caster.get_tree().call_group("damage_tracker", "record_shielding", caster.get_instance_id(), shield_amount)
