class_name NetworkGambit
extends Gambit
## M-PATH B (Networked): lays a rectangular field where it covers the most allies. For the
## duration it keeps evening out the health of every ally inside (see NetworkField).
##   B1: allies inside have more wards.  B2: allies inside have more health regen.

## Field size: Width Cells hexes across, Depth Rows rows deep.
@export var width_cells: float = 3.0
@export var depth_rows: float = 2.0
@export var duration: float = 5.0
## How fast health evens out: the share of the gap closed each second.
@export_range(0.0, 2.0, 0.05) var rate: float = 0.6
## B1: wards allies inside gain. 0 = none.
@export var ward_bonus: float = 0.0
## B2: health regen (per second) allies inside gain. 0 = none.
@export var regen_bonus: float = 0.0


## Only worth it when the field would hold at least two allies.
func can_use(caster: BattleUnit) -> bool:
	return _best_rect(caster)["count"] >= 2


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var best: Dictionary = _best_rect(caster)
	if best["count"] < 1:
		return
	var field := NetworkField.new()
	field.source = caster
	field.team = caster.team
	field.credit_id = caster.get_credit_id()
	field.rect = best["rect"]
	field.time_left = duration
	field.rate = rate
	field.ward_bonus = ward_bonus
	field.regen_bonus = regen_bonus
	field.z_index = 1
	caster.get_tree().current_scene.add_child(field)
	caster.show_float_text("Networked", NetworkField.COLOR)


func _size(caster: BattleUnit) -> Vector2:
	return Vector2(width_cells * caster.grid.cell_spacing(), depth_rows * caster.grid.hex_size * 1.5)


## Tries centring the field on each ally and between each pair of allies, and keeps the one
## that holds the most; ties go to the one nearest M-PATH. {"rect", "count"}.
func _best_rect(caster: BattleUnit) -> Dictionary:
	var allies: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and unit.alive and unit.team == caster.team:
			allies.append(unit)
	var centres: Array[Vector2] = []
	for i in allies.size():
		centres.append(allies[i].global_position)
		for j in range(i + 1, allies.size()):
			centres.append((allies[i].global_position + allies[j].global_position) / 2.0)
	var size := _size(caster)
	var best := {"rect": Rect2(caster.global_position - size / 2.0, size), "count": 0}
	var best_distance := INF
	for centre in centres:
		var rect := Rect2(centre - size / 2.0, size)
		var count := 0
		for unit in allies:
			if rect.has_point(unit.global_position):
				count += 1
		var distance := centre.distance_squared_to(caster.global_position)
		if count > best["count"] or (count == best["count"] and distance < best_distance):
			best = {"rect": rect, "count": count}
			best_distance = distance
	return best
