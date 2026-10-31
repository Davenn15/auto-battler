class_name MirrorImageGambit
extends Gambit
## Creates copies of the caster in free cells next to her. Each copy has her current
## stats but only part of her health, extra dodge chance, and no Gambit. They vanish
## after a while.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn
const CLONE_TINT := Color(0.8, 0.85, 1.0, 0.65)       # see-through, slightly blue

@export var clone_count: int = 1
## Each copy's max health, as a fraction of the caster's (0.25 = 25%).
@export_range(0.05, 1.0, 0.05) var health_fraction: float = 0.25
## Dodge chance each copy gets on top of the base passive (0.2 = +20%).
@export_range(0.0, 1.0, 0.01) var extra_dodge: float = 0.2
## Seconds before a copy vanishes.
@export var clone_duration: float = 8.0


## Only casts if there's room next to her for at least one copy.
func can_use(caster: BattleUnit) -> bool:
	return not caster.grid.free_cells_in_range(caster.cell, 1).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var cells := caster.grid.free_cells_in_range(caster.cell, 1)
	for i in mini(clone_count, cells.size()):
		_spawn_clone(caster, cells[i])


func _spawn_clone(caster: BattleUnit, cell: Vector2i) -> void:
	var clone := UNIT_SCENE.instantiate() as BattleUnit
	clone.setup_as_summon(caster, health_fraction)
	caster.get_parent().add_child(clone)   # _ready runs here
	clone.place_at(cell)
	clone.modulate = CLONE_TINT
	caster.get_tree().call_group("battle_manager", "add_summon", clone)
	# After add_summon: start_combat clears statuses, so these must come later.
	clone.add_status(DodgeStatus.new(extra_dodge))
	clone.add_status(SummonLifetimeStatus.new(clone_duration))
