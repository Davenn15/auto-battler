class_name EmpowerStatus
extends Status
## Silt's empowered attacks (see EmpowerPassive): each of the next few attacks gains the Hit
## Effect: deal extra Insight damage (to everyone within Splash Radius of the target, with
## A1). It lasts all combat until the attacks are used, and never blocks Charge.

const TINT := Color(1.0, 0.55, 0.55)   # sprite tint while active
const PROJECTILE_COLOR := Color(1.0, 0.45, 0.75)   # pink

var bonus: float
var insight_scaling: float
var attacks_left: int
var splash_radius: int


func _init(p_bonus: float, p_insight_scaling: float, p_attacks: int, p_splash_radius: int = 0) -> void:
	bonus = p_bonus
	insight_scaling = p_insight_scaling
	attacks_left = p_attacks
	splash_radius = p_splash_radius


func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


## Settled as the attack is made, so it still lands if Silt dies before his shot arrives.
func get_hit_effect(unit: BattleUnit) -> HitEffect:
	return EmpoweredHit.new(unit, Stats.scaled(bonus, insight_scaling, unit.get_stat(Stats.Stat.INSIGHT)), splash_radius)


func on_applied(unit: BattleUnit) -> void:
	if unit.sprite != null:
		unit.sprite.self_modulate = TINT


func on_removed(unit: BattleUnit) -> void:
	if unit.sprite != null:
		unit.sprite.self_modulate = Color.WHITE


func on_attack(unit: BattleUnit) -> void:
	attacks_left -= 1
	if attacks_left <= 0:
		unit.remove_status(self)


func modify_projectile_color(_unit: BattleUnit, _color: Color) -> Color:
	return PROJECTILE_COLOR


## Extra Insight damage to the target (and, with A1, to every enemy around it).
class EmpoweredHit extends HitEffect:
	var shooter_id: int
	var team: int
	var grid: BattleGrid
	var damage: float
	var radius: int

	func _init(shooter: BattleUnit, p_damage: float, p_radius: int) -> void:
		shooter_id = shooter.get_instance_id()   # an id, so it's safe if he dies
		team = shooter.team
		grid = shooter.grid
		damage = p_damage
		radius = p_radius

	func apply(target: BattleUnit, dealt: float, wrack_level: int) -> void:
		if dealt <= 0.0 or not is_instance_valid(grid):
			return   # dodged
		var tree := grid.get_tree()
		var shooter := instance_from_id(shooter_id) as BattleUnit
		for node in tree.get_nodes_in_group("units"):
			var enemy := node as BattleUnit
			if enemy == null or not enemy.alive or enemy.team == team:
				continue
			if enemy != target and (radius <= 0 or grid.get_distance(target.cell, enemy.cell) > radius):
				continue
			var hit := enemy.take_damage(BattleUnit.damage_bonus(shooter_id, enemy, damage),
					wrack_level if enemy == target else 0, Stats.DamageType.INSIGHT, false, shooter)
			tree.call_group("damage_tracker", "record_damage", shooter_id, hit)
