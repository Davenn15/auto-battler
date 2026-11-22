extends Node
## Plays an online match by itself, to test the network code with two copies of the game
## on one computer. Start one copy as host and one as joiner:
##   godot --headless --fixed-fps 60 --path . res://tools/net_test.tscn -- --host
##   godot --headless --fixed-fps 37 --path . res://tools/net_test.tscn -- --join 127.0.0.1
## or alone against the computer with --offline.
## Options: --idle-round N   don't press Ready in round N (lets the planning timer run out)
##          --quit-round N   close the game when round N's planning starts (tests forfeits)
##          --unready-round N   in round N: Ready, then un-ready while waiting, then Ready again
##          --ready-delay S   wait S seconds after planning before pressing Ready
##          --shot <file.png> save a screenshot 6 s into the first fight (needs a window)
## Each copy plans with the computer strategy and prints what happens.



func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var driver := Driver.new()
	driver.idle_round = _int_arg(args, "--idle-round")
	driver.quit_round = _int_arg(args, "--quit-round")
	driver.unready_round = _int_arg(args, "--unready-round")
	driver.ready_delay = maxf(_int_arg(args, "--ready-delay"), 0.0)
	var shot := args.find("--shot")
	driver.shot_path = args[shot + 1] if shot >= 0 and shot + 1 < args.size() else ""
	driver.label = "HOST" if args.has("--host") else "JOIN"
	get_tree().root.add_child.call_deferred(driver)
	Net.match_ready.connect(func(_s): get_tree().change_scene_to_file("res://scenes/match.tscn"))
	Net.connection_failed.connect(func(reason):
		print("[%s] connection failed: %s" % [driver.label, reason])
		get_tree().quit(1)
	)
	if args.has("--offline"):
		driver.label = "OFFLINE"
		get_tree().change_scene_to_file.call_deferred("res://scenes/match.tscn")
	elif args.has("--host"):
		Net.host()
	else:
		var i := args.find("--join")
		Net.join(args[i + 1] if i >= 0 and i + 1 < args.size() else "127.0.0.1")


func _int_arg(args: PackedStringArray, flag: String) -> int:
	var i := args.find(flag)
	return int(args[i + 1]) if i >= 0 and i + 1 < args.size() else -1


class Driver extends Node:
	var label := ""
	var idle_round := -1
	var quit_round := -1
	var unready_round := -1
	var ready_delay := 0.0
	var _unready_stage := 0   # 0 not yet, 1 readied once, 2 un-readied
	var policy := AiPolicy.new()
	var _done_round := -1
	var _wait := 0.0
	var _results_seen := 0
	var shot_path := ""
	var _shot_taken := false

	func _process(delta: float) -> void:
		var game := get_tree().current_scene as MatchGame
		if game == null:
			return
		_wait -= delta
		if _wait > 0.0:
			return
		if shot_path != "" and not _shot_taken and game.phase == MatchGame.Phase.COMBAT and game._combat_time > 6.0:
			_shot_taken = true
			get_viewport().get_texture().get_image().save_png(shot_path)
			print("[%s] screenshot saved" % label)
		match game.phase:
			MatchGame.Phase.PLANNING:
				if _done_round == game.round_number:
					if _unready_stage == 2 and game.round_number == unready_round:
						_unready_stage = 3
						print("[%s] round %d: back in planning after un-readying, readying again" % [label, game.round_number])
					if game.round_number != idle_round:
						game.press_ready()   # offline it waits until the computer has planned
					return
				_done_round = game.round_number
				if game.round_number == quit_round:
					print("[%s] quitting at round %d" % [label, game.round_number])
					get_tree().quit()
					return
				policy.make_plan(game.player, game.combat_number(), 0)
				game.changed()
				if game.round_number == idle_round:
					print("[%s] round %d: not pressing Ready" % [label, game.round_number])
					return
				if ready_delay > 0.0:
					_wait = ready_delay   # Ready comes on a later frame (the branch above)
					return
				game.press_ready()
				_wait = randf_range(0.1, 1.0)
			MatchGame.Phase.WAITING:
				if game.round_number == unready_round and _unready_stage == 0:
					_unready_stage = 1
					_wait = 0.3
				elif game.round_number == unready_round and _unready_stage == 1:
					_unready_stage = 2
					print("[%s] round %d: un-readying" % [label, game.round_number])
					game.press_ready()
			MatchGame.Phase.RESULT:
				if game.combats_done > _results_seen:
					_results_seen = game.combats_done
					print("[%s] after round %d: my HP %d, opponent HP %d" % [label, game.round_number, game.player.hp, game.ai.hp])
				game.continue_after_result()
				_wait = randf_range(0.1, 1.0)
			MatchGame.Phase.GAME_OVER:
				print("[%s] GAME OVER: my HP %d, opponent HP %d | %s" % [label, game.player.hp, game.ai.hp, " / ".join(game.log_lines)])
				get_tree().quit()
