class_name ShardScalingPassive
extends Passive
## Blade shards also deal a share of the triggering attack's damage.

@export_range(0.0, 2.0, 0.05) var share: float = 0.5


func on_battle_start(unit: BattleUnit) -> void:
	unit.add_status(ShardScalingStatus.new(share))
