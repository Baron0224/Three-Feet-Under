# AUDIO check — verifies the CC0 sound assets import and that the footstep/door
# hooks are wired into player.gd, door.gd and dual_seal_door.gd.
# Run: Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 --script res://tests/audio_check.gd
extends SceneTree

const FOOTSTEPS := [
	"res://audio/sfx/footstep/footstep_stone_1.ogg",
	"res://audio/sfx/footstep/footstep_stone_2.ogg",
	"res://audio/sfx/footstep/footstep_stone_3.ogg",
	"res://audio/sfx/footstep/footstep_stone_4.ogg",
	"res://audio/sfx/footstep/footstep_stone_5.ogg",
	"res://audio/sfx/footstep/footstep_stone_6.ogg",
]

var _checks := 0
var _failures := 0


func _init() -> void:
	for path in FOOTSTEPS:
		_check_stream(path)
	_check_stream("res://audio/sfx/stone_door.ogg")
	_check_footstep_script()
	_check_ambience_script()
	_check_source_hook("res://player.gd", ["FootstepSFX", "play_kind", "_step_accum", "TombAmbience", "set_fall_speed"])
	_check_source_hook("res://door.gd", ["stone_door.ogg", "_sfx.play", "_sfx_thud"])
	_check_source_hook("res://dual_seal_door.gd", ["stone_door.ogg", "_sfx.play", "_sfx_thud"])
	_check_source_hook("res://clue_tablet.gd", ["TABLET_SCRAPE", "_sfx.play", "pitch_scale = 0.55 if reading"])
	print("AUDIO CHECK: %d assertions, failures=%d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check_stream(path: String) -> void:
	_checks += 1
	var stream := load(path)
	if stream == null:
		_failures += 1
		printerr("AUDIO FAIL: missing stream ", path)
	elif not (stream is AudioStream):
		_failures += 1
		printerr("AUDIO FAIL: not an AudioStream: ", path)


func _check_footstep_script() -> void:
	_checks += 1
	var script := load("res://footsteps.gd")
	if script == null or not (script is GDScript):
		_failures += 1
		printerr("AUDIO FAIL: footsteps.gd did not load")
		return
	var node: Node = (script as GDScript).new()
	_checks += 1
	if not (node is AudioStreamPlayer3D):
		_failures += 1
		printerr("AUDIO FAIL: footsteps.gd does not extend AudioStreamPlayer3D")
	_checks += 1
	if not node.has_method("play_kind"):
		_failures += 1
		printerr("AUDIO FAIL: footsteps.gd lacks play_kind()")
	node.free()


func _check_ambience_script() -> void:
	_checks += 1
	var script := load("res://ambience.gd")
	if script == null or not (script is GDScript):
		_failures += 1
		printerr("AUDIO FAIL: ambience.gd did not load")
		return
	var node: Node = (script as GDScript).new()
	_checks += 1
	if not (node is AudioStreamPlayer):
		_failures += 1
		printerr("AUDIO FAIL: ambience.gd does not extend AudioStreamPlayer")
	_checks += 1
	if not node.has_method("set_fall_speed"):
		_failures += 1
		printerr("AUDIO FAIL: ambience.gd lacks set_fall_speed()")
	node.free()


func _check_source_hook(path: String, needles: Array) -> void:
	var source: String = FileAccess.get_file_as_string(path)
	_checks += 1
	if source.is_empty():
		_failures += 1
		printerr("AUDIO FAIL: cannot read source ", path)
		return
	for needle in needles:
		_checks += 1
		if not source.contains(needle):
			_failures += 1
			printerr("AUDIO FAIL: %s missing %s" % [path, needle])