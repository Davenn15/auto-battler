class_name CombatTrack
extends Resource
## One piece of combat music and how it lines up with a fight. Saved as a .tres in
## data/music (CombatMusic finds every one there). Which factions it belongs to decides
## when it's picked; leave Factions empty for a track any faction can get.

@export var stream: AudioStream
## Factions whose fights can play this track, by name ("Sword Court", "Obelisk"). Empty =
## any faction (used when a faction has no tracks of its own).
@export var factions: Array[String] = []
## How fast the track plays (2 = twice as fast). Overtime At and Loop From are in the
## track's own seconds, so at speed 2 a part 60 seconds into the file plays 30 seconds in.
@export var speed: float = 1.0
## With a speed other than 1: true keeps the track's pitch (a pitch shift on the Music bus
## undoes the change), false lets it rise and fall with the speed, like a record.
@export var keep_pitch: bool = true
## Seconds into the track (its own time, before Speed) where the overtime part starts.
## If overtime arrives at a different moment than the music expects, it jumps here so the
## two still match.
@export var overtime_at: float = 30.0
## Seconds into the track where the build-up to the overtime part starts. When the fight is
## that long before overtime (Overtime At minus this), the music jumps to the build-up, so
## it ends exactly as overtime starts. Negative = no build-up jump.
@export var buildup_at: float = -1.0
## Where it loops back to once it reaches the end (the overtime part, so a long fight stays
## frantic). Negative = it doesn't loop.
@export var loop_from: float = 30.0
## Volume adjustment for this track (0 = as recorded), to even out tracks.
@export var volume_db: float = 0.0
