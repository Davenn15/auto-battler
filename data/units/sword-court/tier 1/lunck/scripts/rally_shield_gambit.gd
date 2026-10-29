class_name RallyShieldGambit
extends Gambit
## Grants a shield to every ally within range of the caster's Rally passive.

@export var shield_amount: float = 150.0
## Seconds the shield lasts.
@export var duration: float = 5.0
## Whether Lunck shields himself too.
@export var include_self: bool = true
## Used only if the caster has no Rally passive.
@export var fallback_range_cells: int = 2


## Only fires if there's someone to shield, so charge isn't wasted.
func can_use(caster: BattleUnit) -> bool:
	return not _targets(caster).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	# Allies may have moved or died during the Act time, so look again now.
	for ally in _targets(caster):
		ally.add_status(ShieldStatus.new(shield_amount, duration))
		caster.get_tree().call_group("damage_tracker", "record_shielding", caster.get_instance_id(), shield_amount)


func _targets(caster: BattleUnit) -> Array[BattleUnit]:
	return RallyAuraStatus.get_allies_in_range(caster, _range(caster), include_self)


## Reads the range from the caster's Rally passive so the two can't drift apart.
func _range(caster: BattleUnit) -> int:
	for status in caster.statuses:
		if status is RallyAuraStatus:
			return status.range_cells
	return fallback_range_cells
