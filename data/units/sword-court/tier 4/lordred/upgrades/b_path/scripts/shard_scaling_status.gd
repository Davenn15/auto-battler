class_name ShardScalingStatus
extends Status
## Lordred's blade shards also deal a share of the damage of the attack that triggered them.

var shard_attack_share: float   # read by SpiteStatus: 0.5 = half the attack's damage


func _init(p_share: float) -> void:
	shard_attack_share = p_share
