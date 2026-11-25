class_name VoltageStatus
extends Status
## The Voltage keyword (an Obelisk mechanic): stacks a unit builds up, each giving
## STAT_PER_STACK Insight and Celerity. There's no cap. When the unit's Gambit finishes,
## all its Voltage is gone (after the Gambit itself has had the chance to spend it, as
## Battery's does). Units build it near Battery (see GridPassive) and keep their stacks
## when they leave. Shown as a purple number beside the unit.

const COLOR := Color(0.62, 0.3, 1.0)
const LIGHT := Color(0.85, 0.7, 1.0)
const STAT_PER_STACK := 2.0   # Insight and Celerity per stack

var stacks: float = 0.0
## Voltage the unit is given right after its Gambit clears its stacks (Battery B2's
## railgun kill), so it isn't lost in the clearing.
var after_gambit: float = 0.0
var _label: Label


## The unit's Voltage, or null if it has none.
static func of(unit: BattleUnit) -> VoltageStatus:
	if unit == null:
		return null
	for status in unit.statuses:
		if status is VoltageStatus:
			return status
	return null


## The unit's Voltage, giving it one (empty) if it has none.
static func ensure(unit: BattleUnit) -> VoltageStatus:
	var voltage := of(unit)
	if voltage == null:
		voltage = VoltageStatus.new()
		unit.add_status(voltage)
	return voltage


func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


var _owner: BattleUnit


func on_applied(unit: BattleUnit) -> void:
	_owner = unit
	if not KeepsakeVfx.enabled():
		return
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", LIGHT)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.position = Vector2(14, -6)
	_label.z_index = 15
	unit.add_child(_label)
	_show()


func on_removed(_unit: BattleUnit) -> void:
	if is_instance_valid(_label):
		_label.queue_free()


func modify_stat(_unit: BattleUnit, stat: Stats.Stat, value: float) -> float:
	if stat == Stats.Stat.INSIGHT or stat == Stats.Stat.CELERITY:
		return value + floorf(stacks) * STAT_PER_STACK
	return value


func add(amount: float) -> void:
	stacks += _boosted(amount)
	_show()


## Voltage the unit gets right after its Gambit clears its stacks (so it keeps it).
func add_after_gambit(amount: float) -> void:
	after_gambit += _boosted(amount)


## `amount` after the unit's statuses boost it (Status.modify_voltage_gain: Vestibule A1).
func _boosted(amount: float) -> float:
	if _owner == null or not is_instance_valid(_owner):
		return amount
	for status in _owner.statuses:
		amount = status.modify_voltage_gain(_owner, amount)
	return amount


## Takes `amount` off, if there's that much. Returns true if it did.
func spend(amount: float) -> bool:
	if stacks < amount:
		return false
	stacks -= amount
	_show()
	_spent(amount)
	return true


## Tells the unit's statuses it spent `amount` Voltage (Status.on_voltage_spent).
func _spent(amount: float) -> void:
	if amount <= 0.0 or _owner == null or not is_instance_valid(_owner):
		return
	for status in _owner.statuses.duplicate():
		status.on_voltage_spent(_owner, amount)


## The unit's Gambit is over: all its Voltage is gone (then any it's owed after, B2).
func on_gambit_finished(_unit: BattleUnit) -> void:
	var cleared := stacks
	stacks = after_gambit
	after_gambit = 0.0
	_show()
	_spent(cleared)


func _show() -> void:
	if is_instance_valid(_label):
		_label.text = "⚡%d" % floori(stacks)
		_label.visible = stacks >= 1.0
