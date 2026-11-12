class_name GateDeathChargePassive
extends Passive
## GATE.W(A) B: whenever an ally dies (anyone on its team, summons included), it gains a
## burst of Charge. GATE.W(A)'s passive watches the deaths (see GatePassive).

@export var charge: float = 20.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Marker.new(charge))


## Tells GATE.W(A)'s passive how much Charge each ally death gives.
class Marker extends Status:
	var charge: float

	func _init(p_charge: float) -> void:
		charge = p_charge
