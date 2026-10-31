class_name RallyBoostPassive
extends Passive
## Strengthens the unit's Rally aura: more range, and/or Insight for allies in it.
## Needs a RallyPassive on the same unit. Upgrade passives run after the unit's own,
## so the aura already exists when this runs.

## Extra aura range in hex cells. The Rally gambit's shield range grows with it.
@export var range_bonus: int = 0
## Insight the aura gives each ally in range.
@export var insight_bonus: float = 0.0


func on_battle_start(unit: BattleUnit) -> void:
	for status in unit.statuses:
		if status is RallyAuraStatus:
			status.range_cells += range_bonus
			status.insight += insight_bonus
			return
	push_warning("%s: RallyBoostPassive found no Rally aura to boost." % unit.name)
