class_name AiPool
extends RefCounted
## The computer opponent's background copies of the game, kept running for the whole match
## so planning never waits for copies to start (see ai_eval.gd's worker mode). Every
## AiPlanner shares them: a planner submits a job and gets a ticket, then checks the
## ticket each frame until its result is in.
##
## Jobs and results pass through files in a folder of their own: the game writes
## wN_job.json for worker N, the worker writes wN_out.json back. Each file is written
## under another name first and renamed, so neither side reads half a file.
##
## Safety: a worker never starts copies of its own (AiPlanner.is_eval_copy), quits when the
## game's heartbeat file stops being rewritten (the game closed or crashed), and quits after
## half an hour with no work. stop() closes them all; the match calls it when it ends.

## A job with no answer after this long is given up on: its worker is closed (a fresh one
## takes its place) and the job counts as failed.
const TIMEOUT := 120.0
## Seconds between heartbeats: the game rewrites <folder>/heartbeat this often while the
## pool is open, and workers quit once it's ai_eval.STALE_BEAT seconds old.
const BEAT := 2.0

static var _dir := ""
static var _size := 0
static var _workers: Array = []   # {id, pid, ticket (-1 = idle), sent_ms}
static var _queue: Array = []     # [{ticket, job}], waiting for an idle worker
static var _done := {}            # ticket -> {"result": Array, or null if it failed}
static var _cancelled := {}       # tickets whose results nobody wants any more
static var _next_ticket := 1
static var _next_id := 0
static var _beater: Timer
static var _spawn_times: Array = []   # when recent workers were started (msec)
static var _read_tries := {}          # worker id -> failed reads of its result file
## Most workers started in any SPAWN_WINDOW seconds. If they keep dying straight away
## (something is broken), the pool stops replacing them instead of starting copies
## without end; planning then falls back to untested plans.
const SPAWN_WINDOW := 60.0
const MAX_SPAWNS_PER_WINDOW := 36


## Makes sure `count` workers are running, starting any that are missing. Call it as a
## match starts, so they're ready by the first planning phase.
static func start(count: int) -> void:
	if AiPlanner.is_eval_copy():
		push_error("AiPool: a background copy tried to start copies; refusing.")
		return
	_size = maxi(count, 1)
	if _dir.is_empty():
		_clear_stale_folders()
		_dir = ProjectSettings.globalize_path("user://ai/pool_%d_%d" % [OS.get_process_id(), Time.get_ticks_msec()])
		DirAccess.make_dir_recursive_absolute(_dir)
	if not is_instance_valid(_beater):
		_beater = Timer.new()
		_beater.wait_time = BEAT
		_beater.process_mode = Node.PROCESS_MODE_ALWAYS   # keeps beating while the game is paused
		_beater.timeout.connect(_beat)
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_beater)
		_beater.autostart = true
	_beat()
	_workers = _workers.filter(func(w): return OS.is_process_running(w["pid"]) or w["ticket"] != -1)
	while _workers.size() < _size:
		if not _spawn():
			break


static func _spawn() -> bool:
	var now := Time.get_ticks_msec()
	_spawn_times = _spawn_times.filter(func(t): return now - t < SPAWN_WINDOW * 1000.0)
	if _spawn_times.size() >= MAX_SPAWNS_PER_WINDOW:
		push_warning("AiPool: background copies keep closing; not starting more for now.")
		return false
	_spawn_times.append(now)
	var id := _next_id
	_next_id += 1
	DirAccess.remove_absolute(_path(id, "job"))
	DirAccess.remove_absolute(_path(id, "out"))
	# The copy starts at the main menu, which sends it straight to the evaluation scene
	# when it sees --ai-eval (an exported game can't be told which scene to open). From
	# the editor it also needs to be told where the project is.
	var args := PackedStringArray(["--headless", "--fixed-fps", "60"])
	if not OS.has_feature("template"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--", "--ai-eval", "--worker", "--dir", _dir, "--id", str(id)])
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		push_warning("AiPool: couldn't start a background copy.")
		return false
	_workers.append({"id": id, "pid": pid, "ticket": -1, "sent_ms": 0})
	return true


## Queues `job` (ai_eval.gd's input) for the next idle worker. `count`: how many workers
## there should be. Returns a ticket for take().
static func submit(job: Dictionary, count: int) -> int:
	start(count)
	var ticket := _next_ticket
	_next_ticket += 1
	job["ticket"] = ticket
	_queue.append({"ticket": ticket, "job": job})
	pump()
	return ticket


## The result for `ticket` once it's in, as {"result": Array} ({"result": null} if the
## job failed), or null while it's still running. Each result is handed out once.
static func take(ticket: int):
	if not _done.has(ticket):
		return null
	var entry = _done[ticket]
	_done.erase(ticket)
	return entry


## Nobody wants `ticket`'s result any more (the planner was closed mid-plan).
static func cancel(ticket: int) -> void:
	_queue = _queue.filter(func(q): return q["ticket"] != ticket)
	_done.erase(ticket)
	for w in _workers:
		if w["ticket"] == ticket:
			_cancelled[ticket] = true


## Collects finished results and hands queued jobs to idle workers. Planners call it every
## frame while they wait.
static func pump() -> void:
	if _dir.is_empty():
		return
	var now := Time.get_ticks_msec()
	for w in _workers.duplicate():
		if w["ticket"] == -1:
			continue
		var out := _path(w["id"], "out")
		if FileAccess.file_exists(out):
			var text := FileAccess.get_file_as_string(out)
			var parsed = JSON.parse_string(text) if not text.is_empty() else null
			if parsed == null and _read_tries.get(w["id"], 0) < 30:
				# Just renamed into place, and something (often a virus scanner) still has
				# it open: try again next frame.
				_read_tries[w["id"]] = _read_tries.get(w["id"], 0) + 1
				continue
			_read_tries.erase(w["id"])
			DirAccess.remove_absolute(out)
			var ticket: int = w["ticket"]
			w["ticket"] = -1
			if typeof(parsed) == TYPE_ARRAY and not parsed.is_empty() \
					and typeof(parsed[-1]) == TYPE_DICTIONARY and int(parsed[-1].get("ticket", -1)) == ticket:
				parsed.pop_back()
				_finish(ticket, parsed)
			else:
				_finish(ticket, null)
		elif not OS.is_process_running(w["pid"]) or (now - w["sent_ms"]) / 1000.0 > TIMEOUT:
			if OS.is_process_running(w["pid"]):
				OS.kill(w["pid"])
			_finish(w["ticket"], null)
			_workers.erase(w)
	# Replace any worker that quit or was closed.
	_workers = _workers.filter(func(w): return w["ticket"] != -1 or OS.is_process_running(w["pid"]))
	if not _queue.is_empty() and _workers.size() < _size:
		start(_size)
	for w in _workers:
		if _queue.is_empty():
			break
		if w["ticket"] != -1:
			continue
		var next: Dictionary = _queue.pop_front()
		var path := _path(w["id"], "job")
		var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
		file.store_string(JSON.stringify(next["job"]))
		file.close()
		DirAccess.rename_absolute(path + ".tmp", path)
		w["ticket"] = next["ticket"]
		w["sent_ms"] = now


static func _beat() -> void:
	if _dir.is_empty():
		return
	var file := FileAccess.open(_dir.path_join("heartbeat"), FileAccess.WRITE)
	if file != null:
		file.store_string(str(Time.get_unix_time_from_system()))
		file.close()


static func _finish(ticket: int, result) -> void:
	if _cancelled.has(ticket):
		_cancelled.erase(ticket)
		return
	_done[ticket] = {"result": result}


## Closes every worker and forgets every job. The match calls it when it ends.
static func stop() -> void:
	for w in _workers:
		if OS.is_process_running(w["pid"]):
			OS.kill(w["pid"])
	_workers.clear()
	if is_instance_valid(_beater):
		_beater.queue_free()
	_beater = null
	_queue.clear()
	_done.clear()
	_cancelled.clear()
	if not _dir.is_empty():
		for file in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(file))
		DirAccess.remove_absolute(_dir)
	_dir = ""
	_size = 0


## Removes pool folders a crashed or killed game left behind (no heartbeat for a minute).
static func _clear_stale_folders() -> void:
	var root := ProjectSettings.globalize_path("user://ai")
	if not DirAccess.dir_exists_absolute(root):
		return
	var now := Time.get_unix_time_from_system()
	for folder in DirAccess.get_directories_at(root):
		if not folder.begins_with("pool_"):
			continue
		var path := root.path_join(folder)
		var beat := path.path_join("heartbeat")
		var last := FileAccess.get_modified_time(beat) if FileAccess.file_exists(beat) else FileAccess.get_modified_time(path)
		if now - last < 60:
			continue   # another game may be using it
		for file in DirAccess.get_files_at(path):
			DirAccess.remove_absolute(path.path_join(file))
		DirAccess.remove_absolute(path)


static func running() -> int:
	return _workers.filter(func(w): return OS.is_process_running(w["pid"])).size()


static func _path(id: int, kind: String) -> String:
	return "%s/w%d_%s.json" % [_dir, id, kind]
