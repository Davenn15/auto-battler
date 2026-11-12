class_name VoltageStatus
extends Status
## BATR.EE's Voltage: stacks it builds up and spends on Volts. Shown as a purple number
## beside it.

const COLOR := Color(0.62, 0.3, 1.0)
const LIGHT := Color(0.85, 0.7, 1.0)

var stacks: float = 0.0
## Most Voltage it can hold; gains past it are lost.
var max_stacks: float = INF
## Extra Charge per second while Voltage is full.
var full_charge_regen: float = 0.0
var _label: Label


## BATR.EE's Voltage, or null if it has none.
static func of(unit: BattleUnit) -> VoltageStatus:
	if unit == null:
		return null
	for status in unit.statuses:
		if status is VoltageStatus:
			return status
	return null


func blocks_charge_gain(_unit: BattleUnit) -> bool:
	return false


func on_applied(unit: BattleUnit) -> void:
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


func add(amount: float) -> void:
	stacks = minf(stacks + amount, max_stacks)
	_show()


func is_full() -> bool:
	return stacks >= max_stacks


func tick(unit: BattleUnit, delta: float) -> void:
	if is_full() and full_charge_regen > 0.0 and unit.active and unit.alive:
		unit.gain_charge(full_charge_regen * delta)


## Takes `amount` off, if there's that much. Returns true if it did.
func spend(amount: float) -> bool:
	if stacks < amount:
		return false
	stacks -= amount
	_show()
	return true


func _show() -> void:
	if is_instance_valid(_label):
		_label.text = "⚡%d" % floori(stacks)
		# Brighter, warmer number while full (and earning extra Charge).
		_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5) if is_full() else LIGHT)
