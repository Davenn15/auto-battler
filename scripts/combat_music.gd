class_name CombatMusic
extends Node
## Plays combat music on the "Music" bus. The match starts it as a fight begins, tells it
## when overtime starts, and stops it when the fight ends.
##
## Changing what plays:
##   - Tracks are CombatTrack resources in data/music; add a .tres there to add a track.
##   - CombatMusic.pick(faction) chooses one for a faction: a random one of that faction's
##     own tracks, or, if it has none, one of the tracks for any faction.
##   - play(track) plays any CombatTrack, so callers can choose differently (by opponent,
##     by round, a fixed track...). MatchGame uses `music_faction` to decide.

const TRACKS_DIR := "res://data/music"
const BUS := &"Music"
const FADE_IN := 0.4
const FADE_OUT := 1.5
const SILENT_DB := -40.0
## If overtime starts more than this far from the track's overtime point, jump to it.
const SYNC_SLACK := 0.4

## The track playing now, or null.
var current: CombatTrack = null
var _player: AudioStreamPlayer = null
var _buildup_started := false   # this fight's jump to the build-up has happened

static var _tracks: Array[CombatTrack] = []
static var _scanned := false


## Every combat track in data/music.
static func all_tracks() -> Array[CombatTrack]:
	if _scanned:
		return _tracks
	_scanned = true
	var dir := DirAccess.open(TRACKS_DIR)
	if dir == null:
		return _tracks
	for file in dir.get_files():
		file = file.trim_suffix(".remap")   # exported games list resources as .tres.remap
		if not file.ends_with(".tres"):
			continue
		var track := load(TRACKS_DIR.path_join(file)) as CombatTrack
		if track != null and track.stream != null:
			_tracks.append(track)
	return _tracks


## A track for `faction`'s fights: one of its own at random, else one for any faction.
## Uses the global random numbers, never CombatRng, so music can't change a fight.
static func pick(faction: String) -> CombatTrack:
	var own: Array = all_tracks().filter(func(t): return t.factions.has(faction))
	if own.is_empty():
		own = all_tracks().filter(func(t): return t.factions.is_empty())
	return own[randi() % own.size()] if not own.is_empty() else null


## Starts `track` from the beginning (fading out whatever was playing).
func play(track: CombatTrack) -> void:
	stop(0.2)
	if track == null or track.stream == null or not KeepsakeVfx.enabled():
		return
	GameSettings.ensure_loaded()
	current = track
	_buildup_started = false
	_player = AudioStreamPlayer.new()
	_player.stream = _looping(track)
	_player.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"
	_player.volume_db = SILENT_DB
	_player.pitch_scale = maxf(track.speed, 0.01)
	_set_pitch_shift(1.0 / maxf(track.speed, 0.01) if track.keep_pitch else 1.0)
	add_child(_player)
	_player.play()
	_player.create_tween().tween_property(_player, "volume_db", track.volume_db, FADE_IN)


## Called every physics step of a fight with the seconds left until overtime. Once that's
## no more than the build-up's length, the music jumps into the build-up (as far in as the
## time already passed), so the overtime part starts exactly as overtime does.
func tick(seconds_to_overtime: float) -> void:
	if _buildup_started or current == null or current.buildup_at < 0.0 or not is_playing():
		return
	var length := current.overtime_at - current.buildup_at
	if length <= 0.0 or seconds_to_overtime > length:
		return
	_buildup_started = true
	_player.seek(current.buildup_at + (length - maxf(seconds_to_overtime, 0.0)))


## Overtime has started: if the music isn't at its overtime part (the fight ran faster or
## slower than the music), jump there.
func on_overtime() -> void:
	if current == null or not is_instance_valid(_player) or not _player.playing:
		return
	if absf(_player.get_playback_position() - current.overtime_at) > SYNC_SLACK:
		_player.seek(current.overtime_at)


## Fades the music out over `fade` seconds.
func stop(fade: float = FADE_OUT) -> void:
	current = null
	if not is_instance_valid(_player):
		_player = null
		return
	var player := _player
	_player = null
	var tween := player.create_tween()
	tween.tween_property(player, "volume_db", SILENT_DB, maxf(fade, 0.01))
	tween.tween_callback(player.queue_free)


func is_playing() -> bool:
	return is_instance_valid(_player) and _player.playing


## Keeps the Music bus's pitch shift at `pitch` (1 = none, so it's taken off): how a track
## played faster keeps its own pitch.
func _set_pitch_shift(pitch: float) -> void:
	var bus := AudioServer.get_bus_index(BUS)
	if bus < 0:
		return
	for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectPitchShift:
			AudioServer.remove_bus_effect(bus, i)
	if is_equal_approx(pitch, 1.0):
		return
	var shift := AudioEffectPitchShift.new()
	shift.pitch_scale = clampf(pitch, 0.01, 16.0)
	AudioServer.add_bus_effect(bus, shift)


## A copy of the track's stream set to loop back to Loop From (the shared file never changes).
static func _looping(track: CombatTrack) -> AudioStream:
	if track.loop_from < 0.0:
		return track.stream
	var stream := track.stream.duplicate() as AudioStream
	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true
		stream.loop_offset = track.loop_from
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = int(track.loop_from * stream.mix_rate)
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream
