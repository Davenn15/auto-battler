class_name TectonicStatus
extends Status
## Geomond's Tectonic stance: extra attack range, and his attacks become energy waves.

var time_left: float
var range_bonus: int
var wave_half_width: float
var attack_shield: float
var attack_shield_duration: float
var wave_shields_allies: bool
var ward_shred_per_hit: float
var ward_shred_max: float
var wave_max_health_percent: float

func _init(p_duration: float, p_range_bonus: int, p_wave_half_width: float) -> void:
	time_left = p_duration
	range_bonus = p_range_bonus
	wave_half_width = p_wave_half_width


func on_applied(unit: BattleUnit) -> void:
	unit.attack_range += range_bonus
	KeepsakeVfx.magma_pool(unit)   # flowing magma under him while the stance lasts


func on_removed(unit: BattleUnit) -> void:
	unit.attack_range -= range_bonus   # back to melee; he walks in to his next target
	KeepsakeVfx.clear(unit, "VfxMagma")


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)


func create_projectile(unit: BattleUnit) -> Projectile:
	var wave := EnergyWave.new()
	wave.half_width = wave_half_width
	wave.ally_shield = attack_shield if wave_shields_allies else 0.0
	wave.ally_shield_duration = attack_shield_duration
	wave.max_health_percent = wave_max_health_percent
	wave.wrack_multiplier = 1.0 + unit.get_stat(Stats.Stat.WRACK_DAMAGE)
	return wave

## Every attack during the stance shields him.
func on_attack(unit: BattleUnit) -> void:
	if attack_shield > 0.0:
		unit.add_shield(attack_shield, attack_shield_duration, unit.get_instance_id())

func get_hit_effect(unit: BattleUnit) -> HitEffect:
	if ward_shred_per_hit > 0.0:
		# An item can let control effects wrack, shredding more per hit.
		var per_hit := ward_shred_per_hit * unit.wrack_effect_multiplier(Stats.EffectKind.CONTROL)
		return WardShredHitEffect.new(per_hit, ward_shred_max)
	return null
