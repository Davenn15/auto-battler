class_name GatlingBurstGambit
extends Gambit
## Gatling Gateling: shields itself, and for a while its attacks deal extra Insight damage.
## Shield = Shield + Shield Insight Scaling x Insight.
## Extra damage per hit = Hit Damage + Hit Insight Scaling x Insight, fixed when cast.

@export var shield: float = 100.0
@export var shield_insight_scaling: float = 0.6
@export var shield_duration: float = 4.0
@export var hit_damage: float = 25.0
@export var hit_insight_scaling: float = 0.3
@export var duration: float = 6.0


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive or not caster.is_inside_tree():
		return
	var insight := caster.get_stat(Stats.Stat.INSIGHT)
	caster.add_shield(Stats.scaled(shield, shield_insight_scaling, insight), shield_duration, caster.get_credit_id())
	caster.add_status(BurstStatus.new(Stats.scaled(hit_damage, hit_insight_scaling, insight), duration, caster.get_credit_id()))
	KeepsakeVfx.pulse_glow(caster, "VfxGatlingBurst", GateRules.COLOR, duration)
	caster.show_float_text("Overdrive", GateRules.LIGHT)


class BurstStatus extends Status:
	var amount: float
	var time_left: float
	var credit_id: int

	func _init(p_amount: float, p_duration: float, p_credit_id: int) -> void:
		amount = p_amount
		time_left = p_duration
		credit_id = p_credit_id

	func get_hit_effect(_unit: BattleUnit) -> HitEffect:
		return BurstHit.new(amount, credit_id)

	func tick(unit: BattleUnit, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			unit.remove_status(self)


class BurstHit extends HitEffect:
	var amount: float
	var credit_id: int

	func _init(p_amount: float, p_credit_id: int) -> void:
		amount = p_amount
		credit_id = p_credit_id

	func apply(target: BattleUnit, _dealt: float, _wrack_level: int) -> void:
		if not target.alive:
			return
		var dealt := target.take_damage(amount, 0, Stats.DamageType.INSIGHT)
		target.get_tree().call_group("damage_tracker", "record_damage", credit_id, dealt)
