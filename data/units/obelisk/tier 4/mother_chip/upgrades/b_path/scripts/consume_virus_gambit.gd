class_name ConsumeVirusGambit
extends Gambit
## MOTHER-CHIP B: pulls every Mono-Virus stack off every enemy and turns each one into a
## new Chip.
##   B1: she gains Voltage, more for each stack consumed.

## B1: Voltage = Voltage + Voltage Per Stack x stacks consumed (0 = none). It's given after
## this Gambit clears her old Voltage, so she keeps it until her next Gambit.
@export var voltage: float = 0.0
@export var voltage_per_stack: float = 0.0


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
		CodeShockEffect.touch(caster.get_instance_id(), enemy)
		if KeepsakeVfx.enabled():
			KeepsakeVfx.recycle_orb(enemy.global_position, caster)
	var chips := ChipPassive.of(caster)
	if chips != null:
		chips.add_chips(consumed)
	if voltage > 0.0 or voltage_per_stack > 0.0:
		var gained := voltage + voltage_per_stack * consumed
		VoltageStatus.ensure(caster).after_gambit += gained
		caster.show_float_text("+%d Voltage" % floori(gained), VoltageStatus.LIGHT)
	caster.show_float_text("+%d Chips" % consumed, ChipPassive.LIGHT)
