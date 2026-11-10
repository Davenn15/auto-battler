class_name RotorStatus
extends Status
## On Glaive while his rotors are out: he can't gain Charge, unless his rotors are cycling
## (A upgrade). Ends when its last rotor is gone.

var cycling: bool
var rotors: Array = []   # GlaiveRotor nodes; untyped so freed ones can be dropped


func _init(p_cycling: bool) -> void:
	cycling = p_cycling


func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return not cycling


func tick(unit: BattleUnit, _delta: float) -> void:
	rotors = rotors.filter(func(r): return is_instance_valid(r) and not r.is_queued_for_deletion())
	if rotors.is_empty():
		unit.remove_status(self)
