class_name ArmyUnit
extends RefCounted
## One unit a player owns, between battles: which unit, its upgrade path, where it stands,
## what it carries and how many Reserve buffs it has. Battles are built from these and
## thrown away afterwards, so the army always comes back exactly as it was.

var data: UnitData
var path: Array[int] = []      # upgrade choices: [] base, [0] = A, [1, 0] = B1, ...
var placed := false            # false = on the bench
var cell := Vector2i.ZERO      # where it stands, from its owner's side (the bottom half)
var items: Array[Keepsake] = []   # Shards and keepsakes on the unit
var buffs := 0                 # Reserve buffs bought once it was fully upgraded


func _init(p_data: UnitData = null) -> void:
	data = p_data


func level() -> int:
	return path.size()


func is_maxed() -> bool:
	return level() >= MatchRules.max_level(data)


## Aura spent on the unit: its buy cost plus its upgrades.
func aura_value() -> int:
	return Economy.unit_aura_value(data.tier, level())


func next_buff_cost() -> int:
	return MatchRules.buff_cost(data.tier, buffs)


func display_name() -> String:
	return data.display_name.capitalize()


## "Garth A1": name and path.
func label() -> String:
	return "%s %s" % [display_name(), RandomTeams.path_label(path)]


func copy() -> ArmyUnit:
	var other := ArmyUnit.new(data)
	other.path = path.duplicate()
	other.placed = placed
	other.cell = cell
	other.items = items.duplicate()
	other.buffs = buffs
	return other


# ---------- Saving to text, for the computer opponent's battle simulations ----------

func to_dict() -> Dictionary:
	return {
		"unit": data.resource_path, "path": Array(path), "placed": placed,
		"cell": [cell.x, cell.y], "items": items.map(func(k): return k.resource_path), "buffs": buffs,
	}


static func from_dict(d: Dictionary) -> ArmyUnit:
	var unit := ArmyUnit.new(load(d["unit"]) as UnitData)
	for step in d["path"]:
		unit.path.append(int(step))
	unit.placed = d["placed"]
	unit.cell = Vector2i(int(d["cell"][0]), int(d["cell"][1]))
	for item_path in d["items"]:
		unit.items.append(load(item_path) as Keepsake)
	unit.buffs = int(d["buffs"])
	return unit


static func army_to_array(army: Array[ArmyUnit]) -> Array:
	return army.map(func(u): return u.to_dict())


static func army_from_array(list: Array) -> Array[ArmyUnit]:
	var army: Array[ArmyUnit] = []
	for d in list:
		army.append(from_dict(d))
	return army


static func copy_army(army: Array[ArmyUnit]) -> Array[ArmyUnit]:
	var out: Array[ArmyUnit] = []
	for unit in army:
		out.append(unit.copy())
	return out
