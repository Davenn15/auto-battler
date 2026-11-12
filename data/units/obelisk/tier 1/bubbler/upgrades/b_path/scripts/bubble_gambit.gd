class_name BubbleGambit
extends Gambit
## Bubbler blows a protective bubble over himself and the cells around him. It stays where
## it was cast for a while; allies inside gain wards (see BubbleZone for the upgrades).

@export var radius_cells: int = 2
@export var duration: float = 6.0
## Added to all three wards of allies inside.
@export var ward_bonus: float = 30.0
@export_group("Upgrades")
## B1: shield each ally inside gains per second, given once a second. 0 = none.
@export var shield_per_second: float = 0.0
## Seconds each of those shields lasts.
@export var shield_duration: float = 3.0
## Enemy shots inside move at this share of their speed (0.5 = half). 1 = no slow.
@export var projectile_slow: float = 1.0
## B2: Celerity enemies inside lose. 0 = none.
@export var enemy_celerity_cut: float = 0.0


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var bubble := BubbleZone.new()
	bubble.setup(caster, radius_cells, duration, ward_bonus)
	bubble.shield_per_second = shield_per_second
	bubble.shield_duration = shield_duration
	bubble.projectile_slow = projectile_slow
	bubble.enemy_celerity_cut = enemy_celerity_cut
	caster.get_tree().current_scene.add_child(bubble)
	bubble.global_position = caster.grid.cell_to_world(caster.cell)
	caster.show_float_text("Bubble", BubbleZone.BUBBLE_COLOR)
