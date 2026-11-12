class_name GateWideBoonPassive
extends Passive
## GATE.W(A) A2: its cast heal and stat boost go to every summoned or revived ally, not
## just the ones it brought in itself (see GatePassive).


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Marker.new())


## Tells GATE.W(A)'s passive to boost every newcomer ally.
class Marker extends Status:
	pass
