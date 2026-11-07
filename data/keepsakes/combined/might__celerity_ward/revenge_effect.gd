class_name RevengeEffect
extends Passive
## Whenever an enemy's attack damages the unit, that enemy gains a stack of Revenge (up to
## a cap). Each stack makes it deal 1% less damage to this unit and take 1% more from it.

@export var per_stack: float = 0.01
@export var max_stacks: int = 10


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(Grudge.new(self))


## On the wearer: hands out stacks, and shrinks hits from enemies who have them.
class Grudge extends Status:
	var effect: RevengeEffect

	func _init(p_effect: RevengeEffect) -> void:
		effect = p_effect

	func on_attacked(unit: BattleUnit, attacker: BattleUnit, dealt: float) -> void:
		if dealt > 0.0 and is_instance_valid(attacker) and attacker.alive:
			RevengeMark.of(attacker, unit).add(effect.max_stacks)

	func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
		var mark := RevengeMark.find(unit.incoming_attacker, unit)
		return damage * (1.0 - effect.per_stack * mark.stacks) if mark != null else damage


## On the enemy: how much Revenge it has against one wearer, and taking more damage from them.
class RevengeMark extends Status:
	var wearer_id: int
	var per_stack: float
	var stacks: int = 0

	func _init(p_wearer: BattleUnit, p_per_stack: float) -> void:
		wearer_id = p_wearer.get_instance_id()
		per_stack = p_per_stack

	func add(cap: int) -> void:
		stacks = mini(stacks + 1, cap)

	func modify_incoming_damage(unit: BattleUnit, damage: float) -> float:
		var attacker := unit.incoming_attacker
		if attacker != null and attacker.get_instance_id() == wearer_id:
			return damage * (1.0 + per_stack * stacks)
		return damage

	static func find(enemy, wearer: BattleUnit) -> RevengeMark:
		if not is_instance_valid(enemy):
			return null
		for status in enemy.statuses:
			if status is RevengeMark and status.wearer_id == wearer.get_instance_id():
				return status
		return null

	static func of(enemy: BattleUnit, wearer: BattleUnit) -> RevengeMark:
		var mark := find(enemy, wearer)
		if mark == null:
			var grudge: Grudge = null
			for status in wearer.statuses:
				if status is Grudge:
					grudge = status
			mark = RevengeMark.new(wearer, grudge.effect.per_stack if grudge != null else 0.01)
			enemy.add_status(mark)
		return mark
