class_name KeepsakeForge
extends RefCounted
## Where in-combat Shard and Keepsake making is announced (Shrapnel Forge listens): Gift,
## Surplus, Scavenge, Column's Fabricator and Replication Feed call created().


## `unit` just created `item` (a Shard counts 1, a Keepsake 2).
static func created_item(unit: BattleUnit, item: Keepsake) -> void:
	if item != null:
		created(unit, 1 if item.is_shard else 2)


## `unit` just created `pieces` worth of Shards and Keepsakes.
static func created(unit: BattleUnit, pieces: int) -> void:
	if unit == null or not is_instance_valid(unit) or not unit.alive or pieces <= 0:
		return
	for status in unit.statuses.duplicate():
		status.on_keepsake_created(unit, pieces)
