class_name RecycleLeechEffect
extends Passive
## Recycloid's hero Ascension: he heals for Share of his Gambit damage (Vacuum, on the base
## Gambit and A) and of the damage his revived ally deals (B's Repurposed copy).

## 0.5 = heals for half of that damage.
@export var share: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	var status := LeechStatus.new()
	status.share = share
	unit.add_status(status)


## On Recycloid.
class LeechStatus extends Status:
	var share: float

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_damage(unit: BattleUnit, _target: BattleUnit, amount: float) -> void:
		if amount > 0.0 and unit.alive:
			unit.heal(amount * share, unit.get_instance_id(), false)

	## His only summon is the Repurposed copy: it feeds him with every hit it lands.
	func on_summoned(unit: BattleUnit, summon: BattleUnit) -> void:
		var feed := FeedStatus.new()
		feed.share = share
		feed.recycloid_id = unit.get_instance_id()
		summon.add_status(feed)


## On the revived copy: heals Recycloid for Share of each hit it lands.
class FeedStatus extends Status:
	var share: float
	var recycloid_id: int

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_damage_landed(_unit: BattleUnit, _target: BattleUnit, dealt: float) -> void:
		var recycloid := instance_from_id(recycloid_id) as BattleUnit if is_instance_id_valid(recycloid_id) else null
		if recycloid != null and recycloid.alive:
			recycloid.heal(dealt * share, recycloid_id, false)
