class_name Sfx
extends RefCounted
## Sound effects: one-shot sounds on the "Sounds" bus (default_bus_layout.tres), so a volume
## setting can turn them all up or down later. Each play gets a slight random pitch so
## repeats don't sound identical, and only a few copies of one sound play at once, so a
## wipe of many units doesn't stack into a loud burst. Silent in sims and headless runs.
## Pitch uses the global random numbers, never CombatRng, so sound can't change a fight.

const UNIT_DEATH := preload("res://assets/sfx/unit_death.wav")
const MELEE_ATTACK := preload("res://assets/sfx/melee_attack.wav")
const RANGED_ATTACK := preload("res://assets/sfx/ranged_attack.wav")
const BEAM_LOOP := preload("res://assets/sfx/beam_loop.wav")   # loops while a Beam fires (see Loop)
const GAMBIT_CAST := preload("res://assets/sfx/gambit_cast.wav")   # a Gambit's cast time starts
const GAMBIT_PLAY := preload("res://assets/sfx/gambit_play.wav")   # a Gambit is played
const SPEND_AURA := preload("res://assets/sfx/spend_aura.wav")
const SPEND_RESERVE := preload("res://assets/sfx/spend_reserve.wav")
const ORB_FORM := preload("res://assets/sfx/orb_form.wav")   # the player damage orb appears
const ORB_HIT := preload("res://assets/sfx/orb_hit.wav")     # it hits a player's bar
const READY := preload("res://assets/sfx/ready.wav")         # you ready up for combat
## The combat countdown: 3, 2, 1 (rising), then GAMBIT.
const COUNTDOWN_TICKS: Array[AudioStream] = [
	preload("res://assets/sfx/countdown_tick1.wav"),
	preload("res://assets/sfx/countdown_tick2.wav"),
	preload("res://assets/sfx/countdown_tick3.wav"),
]
const COUNTDOWN_GAMBIT := preload("res://assets/sfx/countdown_gambit.wav")
const RITUAL := preload("res://assets/sfx/ritual.wav")
const MATCH_WIN := preload("res://assets/sfx/match_win.wav")     # the match is won: a fanfare
const MATCH_LOSE := preload("res://assets/sfx/match_lose.wav")   # the match is lost: a sad guitar   # combining or Empowering at the ritual table

const BUS := &"Sounds"
## Most copies of one sound playing at the same time.
const MAX_SAME := 3


## Plays `stream` once. `volume_db` adjusts it (0 = as recorded); `pitch_jitter` is how far
## the pitch may wander either way (0.06 = up to 6%).
static func play(tree: SceneTree, stream: AudioStream, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if tree == null or stream == null or not KeepsakeVfx.enabled():
		return
	GameSettings.ensure_loaded()   # the saved volume, before the first sound
	var group := "sfx_%d" % stream.get_instance_id()
	if tree.get_nodes_in_group(group).size() >= MAX_SAME:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"
	player.add_to_group(group)
	player.finished.connect(player.queue_free)
	tree.root.add_child(player)
	player.play()


## A sound that keeps playing while something lasts (a Beam firing), started and stopped by
## whoever owns it: call set_playing every frame or whenever it changes. The player sits on
## the owner's node, so it goes when the owner does. Only Max Count of one Group play at
## once; one that couldn't start tries again on the next call. Fades in and out briefly.
class Loop extends RefCounted:
	const FADE_IN := 0.06
	const FADE_OUT := 0.12
	const SILENT_DB := -40.0

	var stream: AudioStream
	var group: StringName
	var max_count: int
	var volume_db: float
	var _player: AudioStreamPlayer = null

	func _init(p_stream: AudioStream, p_group: StringName, p_max_count: int = 3, p_volume_db: float = 0.0) -> void:
		stream = p_stream
		group = p_group
		max_count = p_max_count
		volume_db = p_volume_db

	func set_playing(owner: Node, on: bool) -> void:
		if on:
			_start(owner)
		else:
			stop()

	func _start(owner: Node) -> void:
		if is_instance_valid(_player):
			return
		if owner == null or not owner.is_inside_tree() or stream == null or not KeepsakeVfx.enabled():
			return
		if owner.get_tree().get_nodes_in_group(group).size() >= max_count:
			return
		GameSettings.ensure_loaded()
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"
		player.volume_db = SILENT_DB
		player.add_to_group(group)
		owner.add_child(player)
		player.play()
		player.create_tween().tween_property(player, "volume_db", volume_db, FADE_IN)
		_player = player

	## Fades it out and lets the next one in its group start.
	func stop() -> void:
		if not is_instance_valid(_player):
			_player = null
			return
		var player := _player
		_player = null
		player.remove_from_group(group)
		var tween := player.create_tween()
		tween.tween_property(player, "volume_db", SILENT_DB, FADE_OUT)
		tween.tween_callback(player.queue_free)
