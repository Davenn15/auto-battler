class_name CrescendoStatus
extends Status
## Prancelot's crescendo: extra Celerity, and his notes are stronger.

var time_left: float
var celerity_bonus: float
var note_potency: float   # read by NoteStatus.potency: 1.5 = notes 50% stronger


func _init(p_duration: float, p_celerity_bonus: float, p_note_potency: float) -> void:
	time_left = p_duration
	celerity_bonus = p_celerity_bonus
	note_potency = p_note_potency


## Pink notes float around him while it lasts.
func on_applied(unit: BattleUnit) -> void:
	KeepsakeVfx.note_swirl(unit)


func on_removed(unit: BattleUnit) -> void:
	KeepsakeVfx.clear(unit, "VfxCrescendo")


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	return value + celerity_bonus if stat == Stats.Stat.CELERITY else value


func tick(unit: BattleUnit, delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		unit.remove_status(self)
