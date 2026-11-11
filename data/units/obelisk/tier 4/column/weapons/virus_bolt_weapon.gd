class_name ColumnVirusBoltWeapon
extends ColumnWeapon
## A2: fires a Mono-Virus bolt at a random enemy in range; it gives Stacks of Mono-Virus.

@export var stacks: int = 2


func fire(unit: BattleUnit) -> bool:
	var enemies := ColumnWeapon.enemies_in_range(unit, unit.attack_range)
	if enemies.is_empty():
		return false
	var target: BattleUnit = CombatRng.pick(enemies)
	Volt.fire(unit.get_parent(), unit.global_position, target, MonoVirusStatus.SETTINGS.color, 0.0,
			_on_hit.bind(unit.get_instance_id()))
	return true


func _on_hit(target: BattleUnit, caster_id: int) -> void:
	if is_instance_valid(target) and target.alive:
		MonoVirusStatus.infect(target, stacks, caster_id)
