class_name GloryAuraPassive
extends Passive
## Brogaine A1: his passive's aura and Regeneration share each grow by Per Glory for every
## Glory he has (earlier fights and this one). HeartyAuraPassive reads it; it does nothing
## on its own.

@export_range(0.0, 1.0, 0.05) var per_glory: float = 0.15
