class_name PistolShot
extends Projectile
## Von Carrow's pistol shot: a normal attack projectile shaped like a small sword.


func setup(p_shooter: BattleUnit, p_target: BattleUnit, p_damage: float, p_color: Color, p_wrack_level: int = 0, p_type: int = 0, p_hit_effects: Array[HitEffect] = []) -> void:
	super.setup(p_shooter, p_target, p_damage, p_color, p_wrack_level, p_type, p_hit_effects)
	polygon = PackedVector2Array([Vector2(-6, -2), Vector2(8, 0), Vector2(-6, 2)])


func _physics_process(delta: float) -> void:
	if is_instance_valid(target):
		rotation = (target.global_position - global_position).angle()   # point where it's flying
	super._physics_process(delta)
