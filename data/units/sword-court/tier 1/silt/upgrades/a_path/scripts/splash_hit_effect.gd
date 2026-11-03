class_name SplashHitEffect
extends HitEffect
## Deals damage to every other enemy within `radius` hexes of the target.
## Splash damage doesn't wrack and doesn't build charge.

var shooter_id: int
var team: int
var grid: BattleGrid
var damage: float
var damage_type: int
var radius: int


func _init(shooter: BattleUnit, p_damage: float, p_radius: int) -> void:
	shooter_id = shooter.get_instance_id()   # an id, so it's safe if the shooter dies
	team = shooter.team
	grid = shooter.grid
	damage_type = shooter.get_attack_damage_type()
	damage = p_damage
	radius = p_radius


func apply(target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
	var tree := grid.get_tree()
	for node in tree.get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or enemy == target or not enemy.alive or enemy.team == team:
			continue
		if grid.get_distance(target.cell, enemy.cell) > radius:
			continue
		var dealt := enemy.take_damage(damage, 0, damage_type)
		tree.call_group("damage_tracker", "record_damage", shooter_id, dealt)
