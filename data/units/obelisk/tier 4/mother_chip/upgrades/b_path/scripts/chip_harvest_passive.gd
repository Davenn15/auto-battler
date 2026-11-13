class_name ChipHarvestPassive
extends Passive
## MOTHER-CHIP B2: whenever an ally dies, she absorbs its source code as another Chip
## (switches on ChipPassive's chip_per_ally_death).


func on_battle_start(unit: BattleUnit) -> void:
	# After her ChipPassive's status exists: passives start in list order, and upgrade
	# passives come after the unit's own.
	var chips := ChipPassive.of(unit)
	if chips != null:
		chips.chip_per_ally_death = true
