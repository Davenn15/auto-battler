class_name ColumnPulseWeapon
extends ColumnWeapon
## A (Industrial): each shot pulses damage at every enemy within Radius and gives COLUMN a
## shield, bigger for each enemy the pulse hit.
## Damage = Damage + Might Scaling x Might.
## Shield = max health x (Shield Share + Shield Per Enemy x enemies hit).

@export var radius_cells: int = 1
@export var damage: float = 40.0
@export var might_scaling: float = 0.3
@export_enum("Might", "Insight", "Celerity") var damage_type: int = 0
## Shield as a share of COLUMN's max health (0.04 = 4%), and how long it lasts.
@export_range(0.0, 1.0, 0.01) var shield_share: float = 0.04
## Extra shield share for each enemy the pulse hits.
@export_range(0.0, 1.0, 0.01) var shield_per_enemy: float = 0.02
@export var shield_duration: float = 3.0


func fire(unit: BattleUnit) -> bool:
	var hit := Stats.scaled(damage, might_scaling, unit.get_stat(Stats.Stat.MIGHT))
	var level := unit.roll_effect_wrack(Stats.EffectKind.GAMBIT_DAMAGE)
	hit *= unit.effect_wrack_multiplier(level, Stats.EffectKind.GAMBIT_DAMAGE)
	var hits := 0
	for enemy in ColumnWeapon.enemies_in_range(unit, radius_cells):
		var dealt := enemy.take_damage(hit, level, damage_type, false, unit)
		unit.get_tree().call_group("damage_tracker", "record_damage", unit.get_credit_id(), dealt)
		hits += 1
	unit.add_shield(unit.max_health * (shield_share + shield_per_enemy * hits), shield_duration, unit.get_instance_id())
	if KeepsakeVfx.enabled():
		KeepsakeVfx.missile_blast(unit.get_parent(), unit.global_position,
				(radius_cells + 0.5) * unit.grid.cell_spacing(), ColumnWeapon.COLOR)
	return true   # the shield comes every time, even with nobody to hit
