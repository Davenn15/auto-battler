class_name LinkGambit
extends Gambit
## M-PATH links himself to the nearby ally that has lost the most health this combat. While
## linked, both have more wards and each passes a share of the damage it takes to the other.
##   Bonded (A): a share of the healing either one receives is given to the other too.
##   A1: the link also raises both units' Insight.
##   A2: if the linked ally would die, M-PATH dies instead and heals it.

## How close the ally must be, in hex cells.
@export var range_cells: int = 3
@export var duration: float = 6.0
## Wards both linked units gain.
@export var ward_bonus: float = 20.0
## Share of the damage each one takes that goes to the other instead (0.3 = 30%).
@export_range(0.0, 1.0, 0.05) var damage_share: float = 0.3
## Bonded (A): share of the healing either one receives that the other also gets. 0 = none.
@export_range(0.0, 1.0, 0.05) var heal_share: float = 0.0
## A1: Insight both linked units gain. 0 = none.
@export var insight_bonus: float = 0.0
## A2: share of M-PATH's max health the ally is healed for when he dies in its place.
## 0 = he doesn't.
@export_range(0.0, 1.0, 0.05) var sacrifice_heal: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	return _pick_ally(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var ally := _pick_ally(caster)
	if ally == null:
		return
	# A new link replaces his old one.
	for node in caster.get_tree().get_nodes_in_group("path_links"):
		if node.source == caster:
			node.end()
	var link := PathLink.new()
	link.time_left = duration
	link.ward_bonus = ward_bonus
	link.insight_bonus = insight_bonus
	link.damage_share = damage_share
	link.heal_share = heal_share
	link.sacrifice_heal = sacrifice_heal
	link.add_to_group("path_links")
	caster.get_tree().current_scene.add_child(link)
	link.start(caster, ally)
	caster.show_float_text("Link", PathLink.COLOR)


## The ally within range that has lost the most health this combat; ties go to the nearest.
func _pick_ally(caster: BattleUnit) -> BattleUnit:
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit == caster or not unit.alive or unit.team != caster.team:
			continue
		var distance := caster.grid.get_distance(caster.cell, unit.cell)
		if distance > range_cells:
			continue
		if best == null or unit.damage_taken > best.damage_taken \
				or (unit.damage_taken == best.damage_taken and distance < caster.grid.get_distance(caster.cell, best.cell)):
			best = unit
	return best
