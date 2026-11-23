class_name BubbleGuardEffect
extends Passive
## Bubbler's hero Ascension: allies inside his bubbles, from either Gambit (holding a
## Popping bubble, or standing in the Warding bubble), gain Ward Bonus to each Ward and take
## Projectile Cut less damage from enemy projectiles. Bubbler only carries a marker; the
## bubbles read it (BubbleShieldStatus, BubbleZone).

@export var ward_bonus: float = 20.0
## 0.25 = 25% less damage from projectiles.
@export var projectile_cut: float = 0.25


func on_battle_start(unit: BattleUnit) -> void:
	var marker := Marker.new()
	marker.effect = self
	unit.add_status(marker)


## The marker on Bubbler (by instance id), or null if he doesn't have the Ascension.
static func marker_of(caster_id: int) -> Marker:
	if not is_instance_id_valid(caster_id):
		return null
	var caster := instance_from_id(caster_id) as BattleUnit
	if caster == null:
		return null
	for status in caster.statuses:
		if status is Marker:
			return status
	return null


class Marker extends Status:
	var effect: BubbleGuardEffect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false
