class_name GameSettings
extends RefCounted
## Player settings kept between sessions in user://settings.cfg: the volume of sound
## effects (the "Sounds" bus) and of music (the "Music" bus). Loaded and applied the first
## time anything asks, which is at the latest when the first sound or music plays, so no
## scene has to remember to.

const PATH := "user://settings.cfg"
const SOUNDS_BUS := &"Sounds"
const MUSIC_BUS := &"Music"

static var _loaded := false
static var _effects_volume := 1.0   # 0 = silent, 1 = full
static var _music_volume := 1.0


## Sound effects volume, 0 to 1.
static func effects_volume() -> float:
	ensure_loaded()
	return _effects_volume


## Music volume, 0 to 1.
static func music_volume() -> float:
	ensure_loaded()
	return _music_volume


## Sets the sound effects volume (0 to 1) and applies it at once. `save_now` off while a
## slider is still being dragged; call save() when it's let go.
static func set_effects_volume(value: float, save_now: bool = true) -> void:
	ensure_loaded()
	_effects_volume = clampf(value, 0.0, 1.0)
	_apply()
	if save_now:
		save()


## Sets the music volume (0 to 1), as set_effects_volume.
static func set_music_volume(value: float, save_now: bool = true) -> void:
	ensure_loaded()
	_music_volume = clampf(value, 0.0, 1.0)
	_apply()
	if save_now:
		save()


## Reads the saved settings and applies them, once per run.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		_effects_volume = clampf(float(config.get_value("sound", "effects_volume", 1.0)), 0.0, 1.0)
		_music_volume = clampf(float(config.get_value("sound", "music_volume", 1.0)), 0.0, 1.0)
	_apply()


static func save() -> void:
	ensure_loaded()   # never write defaults over settings that weren't read yet
	var config := ConfigFile.new()
	config.load(PATH)   # keep anything else already in the file
	config.set_value("sound", "effects_volume", _effects_volume)
	config.set_value("sound", "music_volume", _music_volume)
	config.save(PATH)


static func _apply() -> void:
	_apply_bus(SOUNDS_BUS, _effects_volume)
	_apply_bus(MUSIC_BUS, _music_volume)


static func _apply_bus(bus_name: StringName, volume: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
