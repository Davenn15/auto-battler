class_name ReviveGambit
extends Gambit
## GATE.W(A) B: brings back the last allies that died (not summons, and each only once), newest first, each with
## Health Share of its max health. They appear beside GATE.W(A), with their upgrades, buffs
## and items, and count as its own for its cast heal and boost (GatePassive).
## GATE.W(A)'s passive keeps the record of who fell.
##   B1: revived allies come back with full Charge.
##   B2: one more ally.

const UNIT_SCENE := preload("uid://b3w2tay7iu387")   # scenes/battle_unit.tscn

@export var count: int = 1
## Share of its max health a revived ally comes back with (0.4 = 40%).
@export_range(0.05, 1.0, 0.05) var health_share: float = 0.4
## B1: 1 = revived allies come back with full Charge.
@export var full_charge: float = 0.0


## Always casts: with nobody to revive (or no room), the cast still heals and boosts the
## allies GATE.W(A) brought back (GatePassive).
func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive or not caster.is_inside_tree():
		return
	var fallen := GatePassive.fallen(caster)
	if fallen.is_empty():
		caster.show_float_text("Empower", GateRules.LIGHT)
		return
	# Beside GATE.W(A), nearest cells first. Allies there's no room for stay on the record.
	var cells := Replicator.free_cells_near(caster.grid, caster.cell, mini(count, fallen.size()))
	var revived := 0
	for cell in cells:
		_revive(caster, fallen.pop_back(), cell)
		revived += 1
	if revived > 0:
		caster.show_float_text("Revive" if revived == 1 else "Revive x%d" % revived, GateRules.LIGHT)
	else:
		caster.show_float_text("Empower", GateRules.LIGHT)   # no room beside it


func _revive(caster: BattleUnit, record: Dictionary, cell: Vector2i) -> void:
	var unit := UNIT_SCENE.instantiate() as BattleUnit
	unit.data = record["data"]
	unit.team = caster.team
	unit.upgrade_path.assign(record["path"])
	unit.buffs = record["buffs"]
	unit.auto_place = false
	unit.set_meta(GateRules.REVIVED_META, caster.get_instance_id())
	if record["army_index"] >= 0:
		unit.set_meta("army_index", record["army_index"])
	caster.get_parent().add_child(unit)
	for item in record["items"]:   # after add_child: equip recomputes health from the data
		unit.equip(item)
	unit.place_at(cell)
	caster.get_tree().call_group("battle_manager", "add_summon", unit)
	# After add_summon: start_combat sets full health, starting charge and clears statuses.
	unit.set_health(unit.max_health * health_share)
	if full_charge > 0.0:
		unit.fill_charge()
	KeepsakeVfx.gate_glow(unit, 0, GateRules.COLOR)
	KeepsakeVfx.missile_blast(caster.get_parent(), unit.global_position, 40.0, GateRules.COLOR)
	unit.show_float_text("Revived", GateRules.LIGHT)
