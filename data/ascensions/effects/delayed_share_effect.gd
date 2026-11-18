class_name DelayedShareEffect
extends Passive
## An Ascension effect (Grit): Share of the damage the unit takes is dealt to it over
## Duration seconds instead of all at once, like Bescard's Unruly. Units that already
## delay all their damage (Bescard) are unchanged.

@export_range(0.0, 1.0, 0.01) var share: float = 0.2
@export var duration: float = 3.5


func on_battle_start(unit: BattleUnit) -> void:
	if unit.statuses.any(func(s): return s is DelayedDamageStatus):
		return   # Bescard: already holds back every hit
	var status := DelayedDamageStatus.new(duration, share)
	unit.add_status(status)
	# First in the list, so it holds its share before any Shield can absorb it.
	unit.move_status_to_front(status)
