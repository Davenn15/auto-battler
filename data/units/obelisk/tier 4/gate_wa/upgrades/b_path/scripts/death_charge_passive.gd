class_name GateDeathChargePassive
extends Passive
## Gateway B: whenever an ally dies (anyone on its team, summons included), it gains a
## burst of Charge. Gateway's passive watches the deaths (see GatePassive).

@export var charge: float = 20.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Marker.new(charge))


## Tells Gateway's passive how much Charge each ally death gives.
class Marker extends Status:
	var charge: float

	func _init(p_charge: float) -> void:
		charge = p_charge
