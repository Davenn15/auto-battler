class_name GambitDuplicateEffect
extends Passive
## An Ascension effect (Perfect Reflection): whenever the unit casts its Gambit (any Gambit,
## so it works on every path), a duplicate of it appears in a free cell next to it: its
## stats, Health Fraction of its max health, extra dodge, no Gambit, and its Keepsakes.
## It vanishes after Duration. No room next to the unit = no duplicate.

const UNIT_SCENE := preload("res://scenes/battle_unit.tscn")
const TINT := Color(0.8, 0.85, 1.0, 0.65)   # see-through and slightly blue, like Mirror Image

@export_range(0.05, 1.0, 0.05) var health_fraction: float = 0.25
## Dodge chance the duplicate gets on top of its own (0.2 = +20%).
@export_range(0.0, 1.0, 0.01) var extra_dodge: float = 0.2
@export var duration: float = 6.0


func on_battle_start(unit: BattleUnit) -> void:
	if not unit.is_summon:   # summons never cast, but just in case
		unit.add_status(GambitDuplicateStatus.new(self))


class GambitDuplicateStatus extends Status:
	var effect: GambitDuplicateEffect

	func _init(p_effect: GambitDuplicateEffect) -> void:
		effect = p_effect

	func on_gambit(unit: BattleUnit) -> void:
		var cells := unit.grid.free_cells_in_range(unit.cell, 1)
		cells.erase(unit.cell)
		if cells.is_empty():
			return
		var copy := UNIT_SCENE.instantiate() as BattleUnit
		copy.setup_as_summon(unit, effect.health_fraction)
		unit.get_parent().add_child(copy)   # _ready runs here
		copy.place_at(cells[0])
		copy.modulate = TINT
		KeepsakeVfx.smoke_puff(copy)
		unit.get_tree().call_group("battle_manager", "add_summon", copy)
		# After add_summon: start_combat clears statuses, so these must come later.
		copy.add_status(DodgeStatus.new(effect.extra_dodge))
		copy.add_status(SummonLifetimeStatus.new(effect.duration))
		for keepsake in unit.keepsakes:
			if copy.keepsakes.size() >= copy.max_keepsakes():
				break
			copy.swap_keepsake_in_combat(keepsake)
