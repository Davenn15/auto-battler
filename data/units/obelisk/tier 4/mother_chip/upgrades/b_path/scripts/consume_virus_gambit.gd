class_name ConsumeVirusGambit
extends Gambit
## MOTHER-CHIP B: pulls every Mono-Virus stack off every enemy and turns each one into a
## new Chip.
##   B1: a shield on cast, bigger for each stack consumed.

## B1: shield = Shield + Shield Per Stack x stacks consumed (0 = no shield), and how long.
@export var shield: float = 0.0
@export var shield_per_stack: float = 0.0
@export var shield_duration: float = 5.0


func can_use(caster: BattleUnit) -> bool:
	for node in caster.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy != null and enemy.alive and enemy.team != caster.team and MonoVirusStatus.stacks_on(enemy) > 0:
			return true
	return false


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive or not caster.is_inside_tree():
		return
	var consumed := 0
	for node in caster.get_tree().get_nodes_in_group("units"):
		var enemy := node as BattleUnit
		if enemy == null or not enemy.alive or enemy.team == caster.team:
			continue
		var virus := MonoVirusStatus.of(enemy)
		if virus == null or virus.stacks <= 0:
			continue
		consumed += virus.stacks
		virus.stacks = 0
		enemy.remove_status(virus)
		if KeepsakeVfx.enabled():
			KeepsakeVfx.recycle_orb(enemy.global_position, caster)
	var chips := ChipPassive.of(caster)
	if chips != null:
		chips.add_chips(consumed)
	if shield > 0.0 or shield_per_stack > 0.0:
		caster.add_shield(shield + shield_per_stack * consumed, shield_duration, caster.get_instance_id())
	caster.show_float_text("+%d Chips" % consumed, ChipPassive.LIGHT)
