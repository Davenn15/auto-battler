class_name BackupProtocolEffect
extends Passive
## An Ascension effect (Obelisk, Backup Protocol; a chosen unit): the first time it would
## die each combat, it Revives instead with Health Share of its max health (and decays).

@export var health_share: float = 0.3


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(BackupStatus.new(self))


class BackupStatus extends Status:
	var effect: BackupProtocolEffect
	var _used := false

	func _init(p_effect: BackupProtocolEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func prevents_death(unit: BattleUnit) -> bool:
		if _used:
			return false
		_used = true
		Revive.start(unit, unit.max_health * effect.health_share)
		unit.show_float_text("Revived", Revive.COLOR)
		KeepsakeVfx.flourish(unit, Revive.COLOR)
		return true
