class_name RotorGambit
extends Gambit
## Glaive conjures an energy rotor: a blade that circles him for a while, damaging enemies it
## sweeps through (see GlaiveRotor). Normally he can't gain Charge while it's out; with
## Cycling (A) he keeps building Charge and each cast adds another rotor.
## Each hit = Damage + Might Scaling x Might, fixed when cast.

@export var duration: float = 6.0
## Laps per second.
@export var laps_per_second: float = 1.0
## How far out the blade circles, in hexes (1 = sweeps the cells next to him).
@export var radius_cells: float = 1.0
@export var damage: float = 40.0
@export var might_scaling: float = 0.4
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## A: he keeps gaining Charge while rotors are out, so he can stack several.
@export var cycling: bool = false
## A2: wards ignored by rotor hits.
@export var ward_pierce: float = 0.0


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var status: RotorStatus = null
	for s in caster.statuses:
		if s is RotorStatus:
			status = s
	if status == null:
		status = RotorStatus.new(cycling)
		caster.add_status(status)
	var rotor := GlaiveRotor.new()
	rotor.caster = caster
	rotor.time_left = duration
	var spacing := caster.grid.cell_spacing()
	rotor.radius = radius_cells * spacing
	rotor.blade_half = spacing * 0.45
	rotor.laps_per_second = laps_per_second
	rotor.damage = Stats.scaled(damage, might_scaling, caster.get_stat(Stats.Stat.MIGHT))
	rotor.damage_type = damage_type
	rotor.ward_pierce = ward_pierce
	# Extra rotors start spread out around him.
	rotor.angle = TAU * status.rotors.size() / 3.0
	rotor.z_index = 8
	caster.get_tree().current_scene.add_child(rotor)
	rotor.global_position = caster.global_position
	status.rotors.append(rotor)
	caster.show_float_text("Rotor", GlaiveRotor.ROTOR_COLOR)
