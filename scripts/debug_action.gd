class_name DebugGambit
extends Gambit
## Test Action: prints a message and flashes the caster yellow.
## Delete this once you have real Actions.


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	print("%s used %s" % [caster.name, gambit_name])
	caster.modulate = Color(1.0, 0.9, 0.2)
	caster.create_tween().tween_property(caster, "modulate", Color.WHITE, 0.4)
