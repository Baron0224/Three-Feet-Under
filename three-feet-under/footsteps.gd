# FootstepSFX — randomized stone footsteps for the first-person player.
# Samples: Fantozzi's Footsteps (CC0), see res://audio/CREDITS.md.
# One node, attached to the player at runtime; the player script decides WHEN a
# step happens (stride distance / landing), this script decides HOW it sounds.
extends AudioStreamPlayer3D

const KIND_WALK := 0
const KIND_SPRINT := 1
const KIND_CROUCH := 2
const KIND_LAND := 3

const STEP_SAMPLES: Array = [
	preload("res://audio/sfx/footstep/footstep_stone_1.ogg"),
	preload("res://audio/sfx/footstep/footstep_stone_2.ogg"),
	preload("res://audio/sfx/footstep/footstep_stone_3.ogg"),
	preload("res://audio/sfx/footstep/footstep_stone_4.ogg"),
	preload("res://audio/sfx/footstep/footstep_stone_5.ogg"),
	preload("res://audio/sfx/footstep/footstep_stone_6.ogg"),
]

var _last_index := -1


func _ready() -> void:
	max_distance = 16.0
	unit_size = 10.0


## kind: KIND_WALK / KIND_SPRINT / KIND_CROUCH / KIND_LAND
## Pitches stay near 1.0 (a real walker's steps barely vary in pitch — wide
## random shifts were what made the old footsteps sound game-like).
func play_kind(kind: int) -> void:
	var pitch := 0.99 + randf() * 0.02
	var db := -9.0
	match kind:
		KIND_CROUCH:
			pitch = 0.96 + randf() * 0.03
			db = -13.0
		KIND_SPRINT:
			pitch = 1.0 + randf() * 0.02
			db = -4.0
		KIND_LAND:
			pitch = 0.86 + randf() * 0.07
			db = -4.0
	# Real steps differ in loudness as much as in pitch; add natural variation.
	_play_sample(db + randf_range(-1.5, 1.0), pitch)


func play_land() -> void:
	play_kind(KIND_LAND)


func _play_sample(db: float, pitch: float) -> void:
	# Avoid the machine-gun feel of repeating the same sample back to back.
	var i := randi_range(0, STEP_SAMPLES.size() - 1)
	if STEP_SAMPLES.size() > 1 and i == _last_index:
		i = (i + 1) % STEP_SAMPLES.size()
	_last_index = i
	stream = STEP_SAMPLES[i]
	volume_db = db
	pitch_scale = pitch
	play()