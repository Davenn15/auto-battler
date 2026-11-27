extends Node
## Battle benchmark: fights a fixed set of random armies (the same every run for a given
## seed) and prints how long they took and each battle's fingerprint. Run it before and
## after a change to the battle code: the speed should go up and the fingerprints must not
## change (a different fingerprint means the change altered how fights play out).
##
##   godot --headless --fixed-fps 60 --path . res://tools/sim_bench.tscn -- [--battles N] [--seed N] [--arv N] [--lean]
##     --lean   turn on SimMode (the sim-only lean battle mode)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var battles := int(_arg(args, "--battles", "12"))
	var arv := int(_arg(args, "--arv", "50"))
	seed(int(_arg(args, "--seed", "77")))
	SimMode.active = args.has("--lean")
	var roster := MatchRules.roster()
	var armies := []
	for i in battles * 2:
		var army: Array[ArmyUnit] = []
		for pick in RandomTeams.make_team(roster, arv, 9, false, true):
			var u := ArmyUnit.new(pick["data"])
			u.path.assign(pick["path"])
			army.append(u)
		var holder := PlayerState.new()
		holder.units = army
		AiPolicy.lay_out(holder)
		armies.append(army)
	var started := Time.get_ticks_usec()
	var simulated := 0.0
	var fingerprints := PackedStringArray()
	for b in battles:
		var r: Dictionary = await BattleArena.fight(self, armies[b * 2], armies[b * 2 + 1], float(_arg(args, "--limit", "90")), 1000 + b)
		simulated += r["time"]
		fingerprints.append(r["fingerprint"])
	var wall := (Time.get_ticks_usec() - started) / 1000000.0
	print("BENCH lean=%s battles=%d simulated=%.1fs wall=%.2fs speed=%.1fx" % [SimMode.active, battles, simulated, wall, simulated / wall])
	print("FINGERPRINTS " + ",".join(fingerprints))
	get_tree().quit()


func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback
