extends CharacterBody3D
const MOVE_SPEED = 3.0
const MOUSE_SENSITIVITY = 0.002
@onready var camera: Camera3D = $Camera3D
func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _unhandled_input(event: InputEvent) -> void:
	# Esc 释放鼠标
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# 单击游戏画面，重新控制视角
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# 身体左右转，摄像机上下看
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
			camera.rotation.x = clampf(
				camera.rotation.x - event.relative.y * MOUSE_SENSITIVITY,
				deg_to_rad(-80.0),
				deg_to_rad(80.0)
			)
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	var movement := Vector3.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_physical_key_pressed(KEY_W):
			movement.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S):
			movement.z += 1.0
		if Input.is_physical_key_pressed(KEY_A):
			movement.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			movement.x += 1.0
	var direction := (transform.basis * movement).normalized()
	velocity.x = direction.x * MOVE_SPEED
	velocity.z = direction.z * MOVE_SPEED
	move_and_slide()
