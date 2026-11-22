class_name EmpowerTuning
extends Passive
## Silt A and A1: changes his empowered attacks (see EmpowerPassive). Does nothing alone.

## A: this many more empowered attacks each time.
@export var extra_attacks: int = 0
## A1: the empowered Insight damage hits every enemy within this many hexes of the target
## (the target included). 0 = just the target.
@export var splash_radius: int = 0
