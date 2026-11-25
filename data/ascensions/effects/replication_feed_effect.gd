class_name ReplicationFeedEffect
extends Passive
## An Ascension effect (Obelisk, Replication Feed; a chosen unit): each time it plays its
## Gambit it gets Shards random Shards for the rest of combat, the way Vestibule's Gift gives
## them (one it holds combines into a Keepsake; otherwise into a free slot).

@export var shards: int = 1


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(FeedStatus.new(self))


class FeedStatus extends Status:
	var effect: ReplicationFeedEffect

	func _init(p_effect: ReplicationFeedEffect) -> void:
		effect = p_effect

	func blocks_charge_gain(_unit: BattleUnit) -> bool:
		return false

	func on_gambit_played(unit: BattleUnit) -> void:
		for i in effect.shards:
			if not unit.alive or ShardGiftGambit.gift_to(unit, unit) == null:
				return
