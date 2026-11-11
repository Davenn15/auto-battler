class_name ReviveGambit
extends Gambit
## GATE.W(A) B: brings back the last allies that died (not summons), newest first, each with
## Health Share of its max health. They appear beside GATE.W(A), with their upgrades, buffs
## and items. GATE.W(A)'s passive keeps the record of who fell.
##   B1: revived allies also get copies of GATE.W(A)'s keepsakes, as many as they have room for.
##   B2: one more ally.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn

@export var count: int = 2
## Share of its max health a revived ally comes back with (0.4 = 40%).
@export_range(0.05, 1.0, 0.05) var health_share: float = 0.4
## B1: 1 = revived allies get copies of GATE.W(A)'s keepsakes.
@export var copy_keepsakes: float = 0.0


## Only casts if someone has fallen and there's room beside GATE.W(A).
func can_use(caster: BattleUnit) -> bool:
	return not GatePassive.fallen(caster).is_empty() \
			and not Replicator.free_cells_near(caster.grid, caster.cell, 1).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive or not caster.is_inside_tree():
		return
	var fallen := GatePassive.fallen(caster)
	# Beside GATE.W(A), nearest cells first. Allies there's no room for stay on the record.
	var cells := Replicator.free_cells_near(caster.grid, caster.cell, mini(count, fallen.size()))
	var revived := 0
	for cell in cells:
		_revive(caster, fallen.pop_back(), cell)
		revived += 1
	if revived > 0:
		caster.show_float_text("Revive x%d" % revived, GateRules.LIGHT)


func _revive(caster: BattleUnit, record: Dictionary, cell: Vector2i) -> void:
	var unit := UNIT_SCENE.instantiate() as BattleUnit
	unit.data = record["data"]
	unit.team = caster.team
	unit.upgrade_path.assign(record["path"])
	unit.buffs = record["buffs"]
	unit.auto_place = false
	unit.set_meta(GateRules.REVIVED_META, true)
	if record["army_index"] >= 0:
		unit.set_meta("army_index", record["army_index"])
	caster.get_parent().add_child(unit)
	for item in record["items"]:   # after add_child: equip recomputes health from the data
		unit.equip(item)
	unit.place_at(cell)
	caster.get_tree().call_group("battle_manager", "add_summon", unit)
	# After add_summon: start_combat sets full health and clears statuses.
	unit.set_health(unit.max_health * health_share)
	if copy_keepsakes > 0.0:
		for keepsake in caster.keepsakes:
			if unit.keepsakes.size() >= BattleUnit.MAX_KEEPSAKES:
				break
			unit.swap_keepsake_in_combat(keepsake)
	KeepsakeVfx.missile_blast(caster.get_parent(), unit.global_position, 40.0, GateRules.COLOR)
	unit.show_float_text("Revived", GateRules.LIGHT)
