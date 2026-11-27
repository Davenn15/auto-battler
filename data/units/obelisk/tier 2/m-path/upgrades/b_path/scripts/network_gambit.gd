class_name NetworkGambit
extends Gambit
## M-Path B (Networked): emanates a redistribution aura over every hex within Radius Cells
## of him for Duration seconds (it moves with him). Every Interval seconds, the total health
## of the allies inside (him included) is balanced: each ends at the same share of its own
## max health. See NetworkField.
##   B1: one hex larger.
##   B2: balances faster, and each ally inside heals Heal Share of its max health each time.

@export var radius_cells: int = 1
@export var duration: float = 8.0
## Seconds between balances.
@export var interval: float = 3.0
## B2: each ally inside heals this share of its max health on every balance (0.03 = 3%).
@export var heal_share: float = 0.0


## Only worth it with at least one ally besides him inside.
func can_use(caster: BattleUnit) -> bool:
	return NetworkField.allies_within(caster, radius_cells).size() >= 2


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	for node in caster.get_tree().get_nodes_in_group("network_fields"):
		if node.source == caster:
			node.end()   # a recast replaces the last aura
	var field := NetworkField.new()
	field.source = caster
	field.radius_cells = radius_cells
	field.time_left = duration
	field.interval = interval
	field.heal_share = heal_share
	field.z_index = -1   # on the ground, under the units
	field.add_to_group("network_fields")
	caster.get_tree().current_scene.add_child(field)
	field.lock_charge(caster)
	caster.show_float_text("Networked", NetworkField.COLOR)
