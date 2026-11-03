class_name ParryStanceGambit
extends Gambit
#“Takes a fighting stance: extra wards, extra Celerity, and a chance to reflect incoming projectiles.”
## Seconds the stance lasts.
@export var duration: float = 4.0
## Added to all three wards while in the stance.
@export var ward_bonus: float = 40.0
## Added to Celerity while in the stance, so she attacks faster.
@export var celerity_bonus: float = 60.0
## Chance to reflect each incoming projectile (0.35 = 35%).
@export var reflect_chance: float = 0.35
## Shield given when the stance starts. 0 = none.
@export var shield_amount: float = 0.0
## Added to wrack chance for reflected projectiles.
@export var reflect_wrack_bonus: float = 0.0


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	# Recasting refreshes the stance instead of stacking a second one.
	for status in caster.statuses.duplicate():
		if status is ParryStanceStatus:
			caster.remove_status(status)
	caster.add_status(ParryStanceStatus.new(duration, ward_bonus, celerity_bonus, reflect_chance, reflect_wrack_bonus))
	if shield_amount > 0.0:
		caster.add_shield(shield_amount, duration, caster.get_instance_id())
