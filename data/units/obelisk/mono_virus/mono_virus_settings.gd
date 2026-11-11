class_name MonoVirusSettings
extends Resource
## The numbers for Mono-Virus, shared by every Obelisk unit that uses it. Edit them in
## mono_virus.tres, next to this script.

## Share of the carrier's max health each stack deals per second (0.005 = 0.5%).
@export_range(0.0, 0.1, 0.0005) var damage_per_stack: float = 0.005
## The least each stack deals per second, so stacks still matter on units with little max
## health. Each stack deals whichever is higher: this or its share of max health.
@export var min_damage_per_stack: float = 15.0
## The damage type: picks the colour of the damage numbers, and which ward reduces it
## when Ignore Wards is off.
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 1
## On: the damage goes straight through wards.
@export var ignore_wards: bool = true
## On: when the carrier dies, its stacks jump to its nearest living ally.
@export var transfers_on_death: bool = true
## Share of the stacks that jump (1.0 = all of them). Rounded down, but at least 1.
@export_range(0.0, 1.0, 0.05) var transfer_share: float = 1.0
## Seconds between the carrier's virus damage numbers.
@export var number_interval: float = 1.0
## The colour of the glow, damage numbers, jump orb and Injector trail.
@export var color: Color = Color(0.75, 0.35, 1.0)
