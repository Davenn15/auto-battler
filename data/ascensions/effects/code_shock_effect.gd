class_name CodeShockEffect
extends Passive
## MOTHER-CHIP's hero Ascension: the first time her Gambit gives Mono-Virus to an enemy
## (the code spiral, on the base Gambit and A) or takes it off one (B's Harvest), that
## enemy is knocked up for Knock Up seconds. Once per enemy per combat. Her Gambits call
## touch().

@export var knock_up: float = 0.75


func on_battle_start(unit: BattleUnit) -> void:
	var marker := ShockMarker.new()
	marker.effect = self
	unit.add_status(marker)


## Her Gambit just gave Mono-Virus to (or took it off) `enemy`. `caster_id`: MOTHER-CHIP.
static func touch(caster_id: int, enemy: BattleUnit) -> void:
	if not is_instance_id_valid(caster_id) or not is_instance_valid(enemy) or not enemy.alive:
		return
	var caster := instance_from_id(caster_id) as BattleUnit
	if caster == null:
		return
	for status in caster.statuses:
		if status is ShockMarker:
			var id := enemy.get_instance_id()
			if status.shocked.has(id):
				return
			status.shocked[id] = true
			KnockUp.apply(enemy, status.effect.knock_up, caster)
			return


class ShockMarker extends Status:
	var effect: CodeShockEffect
	var shocked := {}   # enemy instance id -> true, once knocked up this combat

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false
