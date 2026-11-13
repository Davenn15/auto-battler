class_name SelfRepairGambit
extends Gambit
## REPLK4NT: heals itself for a share of its max health.

## Share of its max health it heals (0.3 = 30%).
@export_range(0.0, 1.0, 0.05) var heal_share: float = 0.3


## Only worth casting once it's hurt.
func can_use(caster: BattleUnit) -> bool:
	return caster.health < caster.max_health * 0.9


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	caster.heal(caster.max_health * heal_share, caster.get_instance_id())
	if KeepsakeVfx.enabled():
		KeepsakeVfx.heal_flash(caster)
	caster.show_float_text("Repair", Replicator.LIGHT)
