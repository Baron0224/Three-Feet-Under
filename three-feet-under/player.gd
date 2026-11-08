# COPYRIGHT Colormatic Studios
# MIT License; Copyright (c) 2023 Colormatic.
# Minimal adaptation of quality-godot-first-person-2, commit
# 27fab75ca8f6d949d887e9f3f9008c2b0e8bb603, addons/fpc/character.gd.
# Full license and adaptation notes: res://third_party/quality_godot_first_person_2/.
# Project additions: slow walking, capsule clearance, tablet lock, abyss death/reload HUD.
extends CharacterBody3D

const MOVE_SPEED := 3.0
const SPRINT_SPEED := 5.2
const SNEAK_SPEED := 1.2
const CROUCH_SPEED := 1.0
const JUMP_VELOCITY := 3.8
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const STAND_EYE_HEIGHT := 1.6
const CROUCH_EYE_HEIGHT := 0.95
const MOUSE_SENSITIVITY := 0.002
const RESTART_DELAY := 1.2
const ABYSS_DEATH_Y := -5.0
const FootstepSFX := preload("res://footsteps.gd")
const TombAmbience := preload("res://ambience.gd")

@onready var camera: Camera3D = $Camera3D
@onready var body_collision: CollisionShape3D = $CollisionShape3D

var is_crouching := false
var sprint_enabled := false
var is_dead := false
var is_reading := false
var mouse_captured := false
var reload_failed := false
var reload_in_progress := false
var capsule: CapsuleShape3D
var standing_probe: CapsuleShape3D
var has_abyss := false
var death_overlay: ColorRect
var death_message: Label
var sprint_indicator: Label
## Ignore FOCUS_OUT for a short grace period after play starts (editor F6 focus flicker).
var _capture_grace_until_msec := 0
var _footsteps: AudioStreamPlayer3D
var _step_accum := 0.0
var _was_airborne := false
var _ambience: Node


func _ready() -> void:
	add_to_group("player")
	# Never resize a shared scene resource (main and tomb use the same script).
	capsule = body_collision.shape.duplicate() as CapsuleShape3D
	body_collision.shape = capsule
	standing_probe = capsule.duplicate() as CapsuleShape3D
	standing_probe.height = STAND_HEIGHT
	_set_crouching(false)
	floor_snap_length = 0.3
	has_abyss = get_parent().has_node("EastWing/Chasm07")
	_create_controls_hud()
	_footsteps = FootstepSFX.new()
	_footsteps.name = "FootstepSFX"
	add_child(_footsteps)
	_ambience = TombAmbience.new()
	_ambience.name = "TombAmbience"
	add_child(_ambience)
	# Editor F6 often fires FOCUS_OUT during startup; grace + deferred capture keeps look working.
	_capture_grace_until_msec = Time.get_ticks_msec() + 750
	call_deferred("_set_mouse_capture", true)


func _set_mouse_capture(enabled: bool) -> void:
	# Keep interaction state explicit; the headless display driver cannot capture a cursor.
	mouse_captured = enabled
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Prefer a normal bordered window so the OS × is available after Esc.
		if not Engine.is_editor_hint():
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var mode := DisplayServer.window_get_mode()
			if mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN 					or mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		if Time.get_ticks_msec() < _capture_grace_until_msec:
			return
		_set_mouse_capture(false)
		is_reading = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and is_node_ready():
		# Re-assert capture if we still expect FPS look (click also works via capture_mouse).
		if mouse_captured and not is_dead:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func can_interact() -> bool:
	return not is_dead and mouse_captured


func set_reading(value: bool) -> void:
	is_reading = value and not is_dead


func _wants_release_mouse(event: InputEvent) -> bool:
	if event.is_action_pressed("release_mouse"):
		return true
	# Hard fallback if InputMap device filters break Esc matching.
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE
	return false


func _wants_capture_mouse(event: InputEvent) -> bool:
	if event.is_action_pressed("capture_mouse"):
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	return false


func _wants_toggle_sprint(event: InputEvent) -> bool:
	# CapsLock is a toggle key: one press switches sprint on, the next switches it off.
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_CAPSLOCK or event.physical_keycode == KEY_CAPSLOCK
	return false


func toggle_sprint() -> void:
	sprint_enabled = not sprint_enabled
	if sprint_indicator != null:
		if sprint_enabled:
			sprint_indicator.text = "疾跑：开（再按 CapsLock 关闭）"
			sprint_indicator.show()
		else:
			sprint_indicator.text = ""
			sprint_indicator.hide()


func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		if reload_failed and event.is_action_pressed("retry_level") and not event.is_echo():
			_try_reload()
		return
	if _wants_toggle_sprint(event):
		toggle_sprint()
		get_viewport().set_input_as_handled()
	elif _wants_release_mouse(event):
		_set_mouse_capture(false)
		is_reading = false
		get_viewport().set_input_as_handled()
	elif _wants_capture_mouse(event):
		_set_mouse_capture(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and can_interact() and not is_reading:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * MOUSE_SENSITIVITY,
			deg_to_rad(-80.0), deg_to_rad(80.0))


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _in_abyss_death_zone():
		_die()
		return
	var controls_enabled := can_interact() and not is_reading
	if controls_enabled:
		# Adapted hold-crouch state and low-ceiling guard from upstream _handle_state.
		if Input.is_action_pressed("crouch"):
			_set_crouching(true)
		elif is_crouching and _can_stand():
			_set_crouching(false)
	var target_eye := CROUCH_EYE_HEIGHT if is_crouching else STAND_EYE_HEIGHT
	camera.position.y = lerpf(camera.position.y, target_eye, 1.0 - exp(-12.0 * delta))

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	# Adapted upstream non-continuous jump: one press, on floor, not ascending.
	if controls_enabled and Input.is_action_just_pressed("jump") and is_on_floor() and velocity.y <= 0.0 and not is_crouching:
		velocity.y += JUMP_VELOCITY
	var fall_speed := velocity.y

	# Adapted upstream direct movement, without sprint or animation dependencies.
	var input_dir := Vector2.ZERO
	if controls_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction_2d := input_dir.rotated(-rotation.y)
	var speed := MOVE_SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	elif Input.is_action_pressed("sneak"):
		speed = SNEAK_SPEED
	elif sprint_enabled:
		speed = SPRINT_SPEED
	velocity.x = direction_2d.x * speed
	velocity.z = direction_2d.y * speed
	var step_start := global_position
	move_and_slide()
	var ambience := _ambience as TombAmbience
	if ambience:
		# Downward speed -> whoosh intensity (0 on the ground, ramps in a fall).
		ambience.set_fall_speed(maxf(-fall_speed, 0.0))
	if _in_abyss_death_zone():
		_die()

	_update_footsteps(step_start, controls_enabled, fall_speed)


func _update_footsteps(step_start: Vector3, controls_enabled: bool, fall_speed: float) -> void:
	var landed := _was_airborne and is_on_floor()
	var distance := Vector2(global_position.x - step_start.x, global_position.z - step_start.z).length()
	if is_dead or not controls_enabled or not is_on_floor() or distance < 0.0001 or distance > 0.5:
		_step_accum = 0.0
	if landed:
		_step_accum = 0.0
		if not is_dead and fall_speed < -1.5:
			_footsteps.play_land(_footsteps.probe_floor(self), -fall_speed)
	elif controls_enabled and not is_dead and is_on_floor() and distance >= 0.0001 and distance <= 0.5:
		var stride := 1.5 # 3 m/s / 1.5 = 2 steps/s.
		var kind := FootstepSFX.KIND_WALK
		if is_crouching:
			stride = 0.8
			kind = FootstepSFX.KIND_CROUCH
		elif Input.is_action_pressed("sneak"):
			stride = 0.9
			kind = FootstepSFX.KIND_SNEAK
		elif sprint_enabled:
			stride = 1.9
			kind = FootstepSFX.KIND_SPRINT
		_step_accum += distance
		if _step_accum >= stride:
			_step_accum = fmod(_step_accum, stride)
			_footsteps.play_kind(kind, _footsteps.probe_floor(self))
	_was_airborne = not is_on_floor()


func _set_crouching(value: bool) -> void:
	is_crouching = value
	capsule.height = CROUCH_HEIGHT if value else STAND_HEIGHT
	body_collision.position.y = capsule.height * 0.5


func _can_stand() -> bool:
	# Test the whole standing capsule, not just a center ray; ignore our own body.
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_probe
	query.transform = global_transform
	query.transform.origin += global_basis.y * (STAND_HEIGHT * 0.5 + 0.025)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _in_abyss_death_zone() -> bool:
	# Scene-authored root-local death bounds follow the environment, not player scale.
	# The fallback keeps the original 1.0x baseline compatible; main has no abyss.
	if not has_abyss:
		return false
	var bounds: AABB = get_parent().get_meta("abyss_death_bounds",
		AABB(Vector3(13, -1000, -28), Vector3(18, 1000 + ABYSS_DEATH_Y, 19)))
	var p: Vector3 = get_parent().to_local(global_position)
	return bounds.has_point(p)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	_step_accum = 0.0
	_footsteps.stop_all()
	is_reading = false
	velocity = Vector3.ZERO
	_set_mouse_capture(false)
	death_message.text = "你坠入了深渊\n即将从入口重新开始……"
	death_overlay.show()
	# Clear the tablet synchronously, including when death happens during reading.
	var tablet := get_parent().get_node_or_null("ClueTablet")
	if tablet != null and tablet.has_method("close_reading"):
		tablet.close_reading()
	await get_tree().create_timer(RESTART_DELAY, true, false, true).timeout
	if is_inside_tree():
		_try_reload()


func _try_reload() -> void:
	if reload_in_progress:
		return
	reload_in_progress = true
	var error := ERR_UNCONFIGURED
	if get_tree().current_scene != null:
		error = get_tree().reload_current_scene()
	if error != OK:
		reload_in_progress = false
		reload_failed = true
		death_message.text = "重新载入失败（%s）\n按 R 重试，或在编辑器重新运行场景" % error_string(error)
		push_warning("Level restart failed: " + error_string(error))


func _create_controls_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PlayerControlsHUD"
	layer.layer = 30
	add_child(layer)
	var controls := Label.new()
	controls.name = "ControlsHint"
	layer.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_top = -72.0
	controls.offset_bottom = -16.0
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_theme_font_size_override("font_size", 18)
	controls.add_theme_color_override("font_shadow_color", Color.BLACK)
	controls.add_theme_constant_override("shadow_offset_x", 2)
	controls.add_theme_constant_override("shadow_offset_y", 2)
	controls.text = "WASD 移动 · CapsLock 切换疾跑 · 按住 Shift 静步 · 按住 Ctrl 蹲下 · 空格 跳跃\nE 阅读/关闭石板 · Esc 释放鼠标 · 单击重新控制"
	sprint_indicator = Label.new()
	sprint_indicator.name = "SprintIndicator"
	layer.add_child(sprint_indicator)
	sprint_indicator.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	sprint_indicator.offset_left = -420.0
	sprint_indicator.offset_top = -104.0
	sprint_indicator.offset_right = -20.0
	sprint_indicator.offset_bottom = -72.0
	sprint_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sprint_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sprint_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprint_indicator.add_theme_font_size_override("font_size", 18)
	sprint_indicator.add_theme_color_override("font_color", Color(0.95, 0.86, 0.62))
	sprint_indicator.add_theme_color_override("font_shadow_color", Color.BLACK)
	sprint_indicator.add_theme_constant_override("shadow_offset_x", 2)
	sprint_indicator.add_theme_constant_override("shadow_offset_y", 2)
	sprint_indicator.text = ""
	sprint_indicator.hide()
	death_overlay = ColorRect.new()
	death_overlay.name = "DeathOverlay"
	layer.add_child(death_overlay)
	death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_overlay.color = Color(0.02, 0.015, 0.01, 0.92)
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.hide()
	death_message = Label.new()
	death_message.name = "DeathMessage"
	death_overlay.add_child(death_message)
	death_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_message.add_theme_font_size_override("font_size", 30)
	death_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
