extends SceneTree
## Checks that fights play out identically however fast the screen draws, which online
## play needs (both computers play the same fight from the same armies and seed).
##   1. godot --headless --path . -s res://tools/determinism_check.gd -- --make <armies.json>
##   2. run --run <armies.json> with --headless --fixed-fps 60, then 144, 37, 23 ...
##   Every run must print the same RESULT line (fight number, fingerprint, winner).

const SECOND_ROW: Array[String] = ["bremes", "lunck", "wesper", "von carrow", "vere"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[1]
	if args[0] == "--make":
		_make(path)
		quit()
		return
	var host := Node2D.new()
	root.add_child(host)
	current_scene = host
	await process_frame
	var job = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out := PackedStringArray()
	for i in job.size():
		var a := ArmyUnit.army_from_array(job[i]["a"])
		var b := ArmyUnit.army_from_array(job[i]["b"])
		var r: Dictionary = await BattleArena.fight(host, a, b, 180.0, 1000 + i)
		out.append("%d %s w%d" % [i, r["fingerprint"], r["winner"]])
	print("RESULT " + " ".join(out))
	quit()


func _make(path: String) -> void:
	seed(12345)
	var pairs := []
	for i in 16:
		pairs.append({"a": _army(), "b": _army()})
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(pairs))
	f.close()


func _army() -> Array:
	var p := PlayerState.new()
	var policy := AiPolicy.random()
	var combats := randi_range(3, 7)
	for c in range(1, combats + 1):
		p.aura = mini(48, 6 * c)
		p.reserve += 25
		MatchRules.start_planning(p, c)
		policy.make_plan(p, c, 0, SECOND_ROW)
	return ArmyUnit.army_to_array(p.board_units())
