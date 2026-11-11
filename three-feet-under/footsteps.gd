# Project-authored surface footsteps; real dry CC0 recordings, see audio/CREDITS.md.
extends AudioStreamPlayer3D
const KIND_WALK := 0
const KIND_SPRINT := 1
const KIND_CROUCH := 2
const KIND_LAND := 3
const KIND_SNEAK := 4
const GAIT_DB := [-9.0, -4.0, -19.0, -3.0, -23.0]
const BANKS := {
	"stone": [preload("res://audio/sfx/footstep/real_stone_1.wav"), preload("res://audio/sfx/footstep/real_stone_2.wav"), preload("res://audio/sfx/footstep/real_stone_3.wav"), preload("res://audio/sfx/footstep/real_stone_4.wav"), preload("res://audio/sfx/footstep/real_stone_5.wav"), preload("res://audio/sfx/footstep/real_stone_6.wav")],
	"stone_land": [preload("res://audio/sfx/footstep/real_stone_land.wav")],
	"gravel": [preload("res://audio/sfx/footstep/real_gravel_1.wav"), preload("res://audio/sfx/footstep/real_gravel_2.wav"), preload("res://audio/sfx/footstep/real_gravel_3.wav"), preload("res://audio/sfx/footstep/real_gravel_4.wav"), preload("res://audio/sfx/footstep/real_gravel_5.wav"), preload("res://audio/sfx/footstep/real_gravel_6.wav")],
	"gravel_land": [preload("res://audio/sfx/footstep/real_gravel_land.wav")],
}
var samples: Dictionary = {}
var pool: Array[AudioStreamPlayer3D] = []
var last_indices: Dictionary = {}
var emitted := 0
var surface_type := "stone"
var last_kind := -1
var room_target := 0.12
var reverb: AudioEffectReverb
var generation := 0

func _ready() -> void:
	samples = BANKS
	if AudioServer.get_bus_index("Footsteps") < 0:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, "Footsteps")
		AudioServer.set_bus_send(index, "Master")
		var effect := AudioEffectReverb.new()
		effect.dry = 1.0
		effect.wet = 0.12
		effect.room_size = 0.55
		effect.damping = 0.65
		AudioServer.add_bus_effect(index, effect)
	reverb = AudioServer.get_bus_effect(AudioServer.get_bus_index("Footsteps"), 0) as AudioEffectReverb
	for i in 8:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = "Footsteps"
		voice.unit_size = 2.0
		voice.max_distance = 14.0
		add_child(voice)
		pool.append(voice)

func _process(delta: float) -> void:
	if reverb:
		reverb.wet = lerpf(reverb.wet, room_target, 1.0 - exp(-3.0 * delta))

func resolve_surface(collider: Node) -> String:
	var node := collider
	while node:
		if node.has_meta("surface_type"):
			var value := str(node.get_meta("surface_type"))
			return value if samples.has(value) else "stone"
		node = node.get_parent()
	return "stone"

func probe_floor(body: CharacterBody3D) -> String:
	var query := PhysicsRayQueryParameters3D.create(body.global_position + Vector3.UP * 0.25, body.global_position + Vector3.DOWN * 0.65, body.collision_mask, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "stone"
	var collider := hit.collider as Node
	var path := str(collider.get_path()) if collider else ""
	room_target = room_wetness(body.get_parent().to_local(body.global_position))
	return resolve_surface(collider)

# Root-metre acoustic volumes include root-level hub floor colliders.
func room_wetness(p: Vector3) -> float:
	if p.x >= -12.5 and p.x <= 12.5 and p.z >= -42.0 and p.z <= -18.0: return 0.18
	if p.x >= -7.5 and p.x <= 37.5 and p.z >= -105.0 and p.z <= -78.0: return 0.21
	if p.x >= 43.5 and p.x <= 70.5 and p.z >= -105.0 and p.z <= -78.0: return 0.21
	return 0.12

func play_kind(kind: int, surface: String = "stone") -> void:
	if pool.is_empty(): return
	surface_type = surface if samples.has(surface) else "stone"
	var bank: Array = samples[surface_type + "_land"] if kind == KIND_LAND else samples[surface_type]
	var index := randi_range(0, bank.size() - 1)
	if index == int(last_indices.get(surface_type, -1)): index = (index + 1) % bank.size()
	last_indices[surface_type] = index
	var voice: AudioStreamPlayer3D
	for candidate in pool:
		if not candidate.playing:
			voice = candidate
			break
	# Drop excess voices rather than truncating a playing tail.
	if voice == null: return
	voice.stream = bank[index]
	voice.volume_db = GAIT_DB[clampi(kind, 0, 4)] + randf_range(-0.6, 0.6)
	voice.pitch_scale = randf_range(0.985, 1.015)
	voice.play()
	emitted += 1
	last_kind = kind

func play_land(surface: String = "stone", impact: float = 4.0) -> void:
	var token := generation
	play_kind(KIND_LAND, surface)
	# Two independent contacts for a heavier two-foot landing, not an echoed sample.
	if impact > 5.0:
		await get_tree().create_timer(0.045).timeout
		if is_inside_tree() and token == generation: play_kind(KIND_CROUCH, surface)

func stop_all() -> void:
	generation += 1
	for voice in pool:
		voice.stop()
		voice.stream = null

func _exit_tree() -> void:
	stop_all()
