class_name ConstellationGambit
extends Gambit
## A three-part combo, one part per cast, then it starts over:
##   1. Blink to the enemy with the most Insight and strike, with bonus Celerity damage.
##   2. Blink to the enemy with the most Celerity and strike, with bonus Insight damage.
##   3. Blink to the enemy with the most health and strike hard, with both bonuses.
## Each strike is a real attack. Each bonus lands as its own hit right after, of its own
## damage type, and wracks when the attack did.

const STAGE_NAMES := ["I", "II", "III"]
const STAGE_COLOR := Color(0.65, 0.75, 1.0)   # starlight

## Each bonus = Bonus Damage + Bonus Scaling x the caster's matching stat (Celerity for
## the Celerity bonus, Insight for the Insight bonus).
@export var bonus_damage: float = 80.0
@export var bonus_scaling: float = 0.6
## Extra attack damage on the third strike, on top of both bonuses.
@export var finisher_damage: float = 150.0
## Seconds she can't be targeted after each cast. 0 = none.
@export var untargetable_time: float = 0.0

func can_use(caster: BattleUnit) -> bool:
	return not _pick(caster, _stage_of(caster).stage).is_empty()


func execute(caster: BattleUnit) -> void:
	if not is_instance_valid(caster) or not caster.alive:
		return
	var tracker := _stage_of(caster)
	var stage := tracker.stage
	var found := _pick(caster, stage)
	if found.is_empty():
		return
	tracker.stage = (stage + 1) % STAGE_NAMES.size()   # the next cast does the next part
	var target: BattleUnit = found["target"]
	if found["cell"] != caster.cell:
		var from := caster.global_position
		caster.place_at(found["cell"])   # blink: there instantly
		tracker.add_line(caster, from, caster.global_position)
	if untargetable_time > 0.0:
		caster.add_status(UntargetableStatus.new(untargetable_time))
	if stage == STAGE_NAMES.size() - 1:
		tracker.fade_lines()   # the constellation is complete: let it fade
	caster.target = target
	caster.show_float_text(STAGE_NAMES[stage], STAGE_COLOR)

	var id := caster.get_credit_id()
	var wrack_multiplier := 1.0 + caster.get_wrack_damage_against(target)
	var bonuses: Array[HitEffect] = []
	if stage != 1:   # first and third strikes
		bonuses.append(KnifeHitEffect.new(id, _bonus(caster, Stats.Stat.CELERITY), Stats.DamageType.CELERITY, wrack_multiplier))
	if stage != 0:   # second and third strikes
		bonuses.append(KnifeHitEffect.new(id, _bonus(caster, Stats.Stat.INSIGHT), Stats.DamageType.INSIGHT, wrack_multiplier))
	caster.attack_now(target, finisher_damage if stage == 2 else 0.0, 0.0, null, bonuses)


func _bonus(caster: BattleUnit, stat: Stats.Stat) -> float:
	return Stats.scaled(bonus_damage, bonus_scaling, caster.get_stat(stat))


## The caster's combo tracker, made the first time it's needed.
func _stage_of(caster: BattleUnit) -> ComboStageStatus:
	for status in caster.statuses:
		if status is ComboStageStatus:
			return status
	var tracker := ComboStageStatus.new()
	caster.add_status(tracker)
	return tracker


## The enemy this part of the combo goes after, and the cell to blink to next to it:
## highest Insight, highest Celerity, or highest health, falling back to the next best
## if there's no room next to one. Empty if there's nowhere to go.
func _pick(caster: BattleUnit, stage: int) -> Dictionary:
	var enemies: Array[BattleUnit] = []
	for node in caster.get_tree().get_nodes_in_group("units"):
		var unit := node as BattleUnit
		if unit != null and caster._is_valid_target(unit):
			enemies.append(unit)
	enemies.sort_custom(func(a, b): return _score(a, stage) > _score(b, stage))
	for enemy in enemies:
		var landing := _landing_cell(caster, enemy)
		if landing != caster.cell:
			return {"target": enemy, "cell": landing}   # a new cell next to it
		if caster.grid.get_distance(caster.cell, enemy.cell) <= 1:
			return {"target": enemy, "cell": caster.cell}   # boxed in, but already next to it
	return {}


func _score(unit: BattleUnit, stage: int) -> float:
	match stage:
		0:
			return unit.get_stat(Stats.Stat.INSIGHT)
		1:
			return unit.get_stat(Stats.Stat.CELERITY)
	return unit.health


## The free cell next to `enemy` farthest from where the caster stands now, so the blink
## takes her well away from whoever was on her. The caster's own cell if none is free.
func _landing_cell(caster: BattleUnit, enemy: BattleUnit) -> Vector2i:
	var best := caster.cell
	var best_dist := -1.0
	for dir in BattleGrid.DIRECTIONS:
		var cell: Vector2i = enemy.cell + dir
		if not caster.grid.can_place(cell):
			continue
		var dist := caster.global_position.distance_squared_to(caster.grid.cell_to_world(cell))
		if dist > best_dist:
			best_dist = dist
			best = cell
	return best
