class_name OverdriveGambit
extends Gambit
## Scour goes into overdrive: more Might and Celerity for a while, at the cost of burning a
## share of his own max health every second (see OverdriveStatus). Casting again while it's
## running starts it over.

@export var duration: float = 5.0
@export var might_bonus: float = 40.0
## At baseline 100, +60 is 60% faster attacks (so a faster-dealing beam).
@export var celerity_bonus: float = 60.0
## Share of his max health he loses each second while it lasts (0.04 = 4%).
@export var burn_per_second: float = 0.04
## A2: Voltage he builds each second while Overdrive lasts (0 = none).
@export var voltage_per_second: float = 0.0


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	for status in caster.statuses.duplicate():
		if status is OverdriveStatus:
			caster.remove_status(status)
	var overdrive := OverdriveStatus.new(duration, might_bonus, celerity_bonus, burn_per_second)
	overdrive.voltage_per_second = voltage_per_second
	caster.add_status(overdrive)
	caster.show_float_text("Overdrive", OverdriveStatus.OVERDRIVE_GLOW)
