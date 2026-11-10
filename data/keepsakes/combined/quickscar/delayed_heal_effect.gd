class_name DelayedHealEffect
extends Passive
## Whenever the unit takes damage, it heals a share of it back after a delay.

@export var share: float = 0.15
@export var delay: float = 3.0


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Afterglow.new(self))


class Afterglow extends Status:
	var effect: DelayedHealEffect
	var _time := 0.0
	var _due: Array = []   # [time to heal at, amount]

	func _init(p_effect: DelayedHealEffect) -> void:
		effect = p_effect

	func modify_incoming_damage(_unit: BattleUnit, damage: float) -> float:
		if damage > 0.0:
			_due.append([_time + effect.delay, damage * effect.share])
		return damage

	func tick(unit: BattleUnit, delta: float) -> void:
		_time += delta
		while not _due.is_empty() and _due[0][0] <= _time:
			var before := unit.health
			unit.heal(_due.pop_front()[1], unit.get_instance_id())
			if unit.health > before:
				KeepsakeVfx.heal_flash(unit)
