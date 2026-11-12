class_name Volt
extends Node2D
## A purple bolt that flies to a unit and runs `on_hit` (if any) when it gets there: BATR.EE's
## Volts at enemies, and the small jolts allies send it when they give it Voltage.
## Drawn as a jagged line that flickers, trailing back towards where it was fired.

const SPEED := 520.0   # pixels per second
const TRAIL := 28.0    # pixels of zigzag behind the head

var target   # untyped: may be freed in flight
var color: Color = VoltageStatus.COLOR
var on_hit: Callable   # (target: BattleUnit) -> void
## Whatever on_hit belongs to (BATR.EE's own copy of its Gambit), kept alive so a Volt
## still in flight when BATR.EE dies can land.
var _hit_owner: Variant
var _delay := 0.0
var _flicker := 0.0


## Fires a Volt from `from` at `p_target` after `delay` seconds.
static func fire(parent: Node, from: Vector2, p_target: BattleUnit, p_color: Color, delay: float,
		p_on_hit: Callable) -> Volt:
	var volt := Volt.new()
	volt.target = p_target
	volt.color = p_color
	volt.on_hit = p_on_hit
	volt._hit_owner = p_on_hit.get_object()
	volt._delay = delay
	volt.z_index = 14
	volt.visible = delay <= 0.0
	parent.add_child(volt)
	volt.global_position = from
	return volt


func _physics_process(delta: float) -> void:
	if _delay > 0.0:
		_delay -= delta
		visible = _delay <= 0.0
		return
	if not is_instance_valid(target) or not target.alive:
		queue_free()
		return
	var to: Vector2 = target.global_position - global_position
	var step := SPEED * delta
	if to.length() <= step:
		global_position = target.global_position
		if on_hit.is_valid():
			on_hit.call(target)
		queue_free()
		return
	global_position += to.normalized() * step
	rotation = to.angle()


func _process(delta: float) -> void:
	_flicker += delta
	queue_redraw()


func _draw() -> void:
	var points := PackedVector2Array([Vector2.ZERO])
	var segments := 5
	var seed_value := int(_flicker * 30.0)
	for i in range(1, segments + 1):
		var x := -TRAIL * i / segments
		var y := 0.0 if i == segments else (5.0 if (seed_value + i) % 2 == 0 else -5.0)
		points.append(Vector2(x, y))
	draw_polyline(points, Color(color, 0.45), 6.0, true)
	draw_polyline(points, VoltageStatus.LIGHT, 2.0, true)
	draw_circle(Vector2.ZERO, 4.0, VoltageStatus.LIGHT)
