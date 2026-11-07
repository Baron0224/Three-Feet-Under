# TombAmbience — procedural tomb ambience, zero external assets.
# Generates on the fly with an AudioStreamGenerator:
#   - low wind/rumble (brown noise) with a slow swell, so the tomb never feels silent
#   - random water drips (short decaying sine pings), the classic tomb sound
#   - a fall-whoosh the player script drives via set_fall_speed() during a drop
# Attached as a child of the player; it is NOT gated by read/pause state.
extends AudioStreamPlayer

const MIX_RATE := 22050.0
const RUMBLE_FLOOR := 0.020
const RUMBLE_CEIL := 0.055
const WHOOSH_MAX := 0.080

var _playback: AudioStreamGeneratorPlayback
var _t := 0.0

# Rumble voice (brown noise + very slow LFO swell).
var _brown := 0.0
var _lfo_phase := 0.0

# Drip voice.
var _drip_timer := 3.0
var _drip_left := 0.0
var _drip_freq := 900.0
var _drip_amp := 0.0

# Fall whoosh voice.
var _fall_gain := 0.0
var _fall_level := 0.0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.15
	stream = gen
	volume_db = -16.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func set_fall_speed(fall_speed: float) -> void:
	# fall_speed is positive downward speed; drive the whoosh 0..1.
	_fall_gain = clampf(fall_speed / 9.0, 0.0, 1.0)


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	for i in frames:
		var s := _next_sample()
		_playback.push_frame(Vector2(s, s))


func _next_sample() -> float:
	var dt := 1.0 / MIX_RATE
	_t += dt

	# --- rumble -------------------------------------------------------------
	_lfo_phase += dt * TAU / 16.0  # 16 s swell cycle
	var swell := 0.5 + 0.5 * sin(_lfo_phase)
	var rumble_amp := lerpf(RUMBLE_FLOOR, RUMBLE_CEIL, swell)
	_brown = (_brown + (randf() * 2.0 - 1.0) * 0.035) * 0.982
	var rumble := _brown * rumble_amp

	# --- drip ---------------------------------------------------------------
	_drip_timer -= dt
	if _drip_timer <= 0.0 and not _drip_left > 0.0:
		_drip_left = randf_range(0.16, 0.30)
		_drip_freq = randf_range(700.0, 1500.0)
		_drip_amp = randf_range(0.05, 0.10)
		_drip_timer = randf_range(2.5, 6.5)
	var drip := 0.0
	if _drip_left > 0.0:
		_drip_left -= dt
		drip = sin(TAU * _drip_freq * _drip_left) * exp(-_drip_left * 16.0) * _drip_amp

	# --- fall whoosh (smooth attack/release, noise swelling with speed) ------
	_fall_level = move_toward(_fall_level, _fall_gain, dt * 2.2)
	var whoosh := (randf() * 2.0 - 1.0) * _fall_level * WHOOSH_MAX

	return clampf(rumble + drip + whoosh, -1.0, 1.0)