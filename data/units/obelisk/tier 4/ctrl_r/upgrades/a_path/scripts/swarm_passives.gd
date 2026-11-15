class_name CtrlSwarmPassive
extends Passive
## CTRL(R)'s A path, one script for its three passives (set Kind in the .tres):
##   Swarming (A): every siphon launch also sends bore drones (see CtrlDrones).
##   A1: more healing received from every source.
##   A2: every drone that makes it back gives CTRL(R) a Shield.

enum Kind { SWARMING, HEALING, DRONE_SHIELD }
@export var kind: Kind = Kind.SWARMING
@export_group("Swarming (A)")
## Bore drones sent with each siphon drone.
@export var bores_per_siphon: int = 2
## Damage each bore drone deals.
@export var bore_damage: float = 30.0
## Taken off each of the enemy's three wards (for the rest of combat) and given to CTRL(R).
@export var ward_steal: float = 7.0
@export_group("A1")
## Extra healing received (0.4 = +40%).
@export var healing_bonus: float = 0.4
@export_group("A2")
## Shield per returning drone, and how long it lasts.
@export var shield: float = 120.0
@export var shield_duration: float = 4.0


func on_battle_start(unit: BattleUnit) -> void:
	match kind:
		Kind.SWARMING:
			unit.add_status(CtrlDrones.SwarmStatus.new(bores_per_siphon, bore_damage, ward_steal))
		Kind.HEALING:
			unit.add_status(HealingBoost.new(healing_bonus))
		Kind.DRONE_SHIELD:
			unit.add_status(CtrlDrones.DroneShieldStatus.new(shield, shield_duration))


## A1: healing received is multiplied up.
class HealingBoost extends Status:
	var bonus: float

	func _init(p_bonus: float) -> void:
		bonus = p_bonus

	func modify_healing_received(_unit: BattleUnit, amount: float) -> float:
		return amount * (1.0 + bonus)
