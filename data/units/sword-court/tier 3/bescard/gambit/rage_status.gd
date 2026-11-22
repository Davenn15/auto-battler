class_name RageStatus
extends Status
## Bonus Might and Celerity, plus lifesteal on attacks, for a set time.

const TINT := Color(1.0, 0.45, 0.35)   # sprite tint while active

var time_left: float
var might: float
var celerity: float
var lifesteal: float   # fraction of attack damage dealt that heals the unit
var full_duration: float              # for refreshing back to full
var cleanse_on_kill: bool = false     # a kill drops all damage the passive is holding
var kill_extension: float = 0.0       # A2: seconds each kill adds to the rage
var random_targets: bool = false      # picks targets at random while raging


func _init(p_duration: float, p_might: float, p_celerity: float, p_lifesteal: float) -> void:
	time_left = p_duration
	might = p_might
	celerity = p_celerity
	lifesteal = p_lifesteal
	full_duration = p_duration


func on_applied(unit: BattleUnit) -> void:
	if unit.sprite != null:
		unit.sprite.self_modulate = TINT
	KeepsakeVfx.rage_flame(unit, true)
	if random_targets:
		unit.target = modify_target_choice(unit, null, null)   # switch right away


func on_removed(unit: BattleUnit) -> void:
	if unit.sprite != null:
		unit.sprite.self_modulate = Color.WHITE
	KeepsakeVfx.rage_flame(unit, false)
	if random_targets:
		unit.target = null   # back to the nearest enemy


func on_kill(unit: BattleUnit, _victim: BattleUnit) -> void:
	if cleanse_on_kill:
		var grit := Grit.of(unit)
		if grit != null:
			grit.clear()
		unit.show_float_text("Cleansed", TINT)
	if kill_extension > 0.0:
		time_left += kill_extension


func modify_target_choice(unit: BattleUnit, choice: BattleUnit, exclude: BattleUnit) -> BattleUnit:
	if not random_targets:
		return choice
	var options: Array[BattleUnit] = []
	for node in unit.get_tree().get_nodes_in_group("units"):
		var other := node as BattleUnit
		if other != null and other != exclude and unit._is_valid_target(other):
			options.append(other)
	return choice if options.is_empty() else CombatRng.pick(options)


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat == Stats.Stat.MIGHT:
		return value + might
	if stat == Stats.Stat.CELERITY:
		return value + celerity
	if stat == Stats.Stat.VAMPIRISM:
		return value + lifesteal
	return value

func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
