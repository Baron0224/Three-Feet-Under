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
func play_kind(kind: int) -> void:
	var pitch := 0.9 + randf() * 0.15
	var db := -8.0
	match kind:
		KIND_CROUCH:
			pitch = 0.82 + randf() * 0.12
			db = -13.0
		KIND_SPRINT:
			pitch = 1.06 + randf() * 0.14
			db = -4.0
		KIND_LAND:
			pitch = 0.66 + randf() * 0.1
			db = -5.0
	_play_sample(db, pitch)


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