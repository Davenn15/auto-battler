class_name LinkGambit
extends Gambit
## M-Path links himself to the ally within Range Cells that the most enemies are targeting
## (ties: the nearest) for Duration seconds. While linked, both have Regen Bonus health
## regen and Ward Bonus to all three Wards, and each takes Damage Share of the other's damage.
##   A (Bound): the link is permanent. Casting again while it holds heals both for
##      Recast Heal + Recast Heal Insight Scaling x his Insight; if the ally died, it links
##      a new one.
##   A1: both linked units have Might Bonus Might and Vampirism Bonus Vampirism.
##   A2: whenever the linked ally would die, M-Path gives up Sacrifice Share of his current
##       health (never going below 1) and heals it for the same amount.

## How close the ally must be, in hex cells.
@export var range_cells: int = 3
@export var duration: float = 8.0
## Health regen (per second) both linked units gain.
@export var regen_bonus: float = 25.0
## Added to all three Wards of both linked units.
@export var ward_bonus: float = 30.0
## Share of the damage each one takes that goes to the other instead (0.4 = 40%).
@export_range(0.0, 1.0, 0.05) var damage_share: float = 0.4
## A: 1 = the link never runs out.
@export var permanent: float = 0.0
## A: the heal both get when he casts again while linked.
@export var recast_heal: float = 0.0
@export var recast_heal_insight_scaling: float = 0.0
## A1: Might and Vampirism (0.1 = 10%) both linked units gain.
@export var might_bonus: float = 0.0
@export var vampirism_bonus: float = 0.0
## A2: share of M-Path's current health he gives up (and heals the ally for) whenever the
## ally would die. 0 = he doesn't.
@export_range(0.0, 1.0, 0.05) var sacrifice_share: float = 0.0
## Unused (the link used to give Insight). Kept so saved files load.
@export var insight_bonus: float = 0.0


func can_use(caster: BattleUnit) -> bool:
	return _live_link(caster) != null and permanent > 0.0 or _pick_ally(caster) != null


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var current := _live_link(caster)
	if current != null and permanent > 0.0:
		_recast_heal(caster, current)
		return
	var ally := _pick_ally(caster)
	if ally == null:
		return
	# A new link replaces his old one.
	for node in caster.get_tree().get_nodes_in_group("path_links"):
		if node.source == caster:
			node.end()
	var link := PathLink.new()
	link.time_left = INF if permanent > 0.0 else duration
	link.permanent = permanent > 0.0
	link.regen_bonus = regen_bonus
	link.ward_bonus = ward_bonus
	link.might_bonus = might_bonus
	link.vampirism_bonus = vampirism_bonus
	link.damage_share = damage_share
	link.sacrifice_share = sacrifice_share
	link.add_to_group("path_links")
	caster.get_tree().current_scene.add_child(link)
	link.start(caster, ally)
	caster.show_float_text("Link", PathLink.COLOR)


## A: casting again while linked heals both of them.
func _recast_heal(caster: BattleUnit, link: PathLink) -> void:
	var amount := Stats.scaled(recast_heal, recast_heal_insight_scaling, caster.get_stat(Stats.Stat.INSIGHT))
	for unit in [link.source, link.ally]:
		if PathLink._alive(unit) and amount > 0.0:
			unit.heal(amount, caster.get_instance_id(), true, true)
			BattleUnit.gambit_affected(caster, unit)
			PathLink.heal_ring(unit)


## His link that's still holding, or null.
func _live_link(caster: BattleUnit) -> PathLink:
	for node in caster.get_tree().get_nodes_in_group("path_links"):
		if node.source == caster and node.is_live():
			return node
	return null


## The ally within range that the most enemies are targeting; ties go to the nearest.
func _pick_ally(caster: BattleUnit) -> BattleUnit:
	var targeted := {}
	for node in caster.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy != null and enemy.alive and enemy.team != caster.team and is_instance_valid(enemy.target):
			targeted[enemy.target] = targeted.get(enemy.target, 0) + 1
	var best: BattleUnit = null
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit == null or unit == caster or not unit.alive or unit.team != caster.team:
			continue
		var distance := caster.grid.get_distance(caster.cell, unit.cell)
		if distance > range_cells:
			continue
		if best == null:
			best = unit
			continue
		var count: int = targeted.get(unit, 0)
		var best_count: int = targeted.get(best, 0)
		if count > best_count or (count == best_count and distance < caster.grid.get_distance(caster.cell, best.cell)):
			best = unit
	return best
