extends Node3D

@export var respawn_path: NodePath
@export var prompt_path: NodePath = NodePath("../HUD/InteractPrompt")
@export var fire_speed := 16.0
@export var fire_distance := 4.0

var _fired := false
var _flying := false
var _starts: Array[Vector3] = []
var _speeds: Array[float] = []
var _travels: Array[float] = []
var _alive: Array[bool] = []

@onready var _trigger: Area3D = $TriggerArea
@onready var _darts: Node3D = $Darts
@onready var _prompt: Label = get_node_or_null(prompt_path)


func _ready() -> void:
	for dart in _darts.get_children():
		_starts.append(dart.position)
		_speeds.append(fire_speed * randf_range(0.75, 1.25))
		_travels.append(0.0)
		_alive.append(false)
		dart.visible = false
		var hit: Area3D = dart.get_node("HitArea")
		hit.body_entered.connect(_on_hit)
	_trigger.body_entered.connect(_on_trigger)


func _on_trigger(body: Node) -> void:
	if _fired:
		return
	if not body.is_in_group("player"):
		return
	_fire()


func _fire() -> void:
	_fired = true
	_flying = true
	var i := 0
	for dart in _darts.get_children():
		dart.position = _starts[i]
		dart.visible = true
		_travels[i] = 0.0
		_alive[i] = true
		i += 1
	if _prompt:
		_prompt.visible = true
		_prompt.text = "Dart!"


func _process(delta: float) -> void:
	if not _flying:
		return
	var any_flying := false
	var i := 0
	for dart in _darts.get_children():
		if _alive[i]:
			var step: float = _speeds[i] * delta
			var pos: Vector3 = dart.position
			pos.z += step
			pos.x += sin(_travels[i] * 3.0 + float(i)) * 0.002
			dart.position = pos
			_travels[i] += step
			if _travels[i] >= fire_distance:
				dart.position = Vector3(pos.x, pos.y, _starts[i].z + fire_distance)
				_alive[i] = false
			else:
				any_flying = true
		i += 1
	if not any_flying:
		_flying = false
		if _prompt:
			_prompt.visible = false


func _on_hit(body: Node) -> void:
	if not _flying:
		return
	if not body.is_in_group("player"):
		return
	_stick_all()
	_respawn(body)


func _stick_all() -> void:
	_flying = false
	var i := 0
	for dart in _darts.get_children():
		if _alive[i]:
			var pos: Vector3 = dart.position
			dart.position = Vector3(pos.x, pos.y, _starts[i].z + fire_distance)
		_alive[i] = false
		dart.visible = true
		i += 1
	if _prompt:
		_prompt.visible = false


func _respawn(body: Node) -> void:
	var marker := get_node_or_null(respawn_path)
	if marker and body is Node3D:
		body.global_position = marker.global_position
		if body is CharacterBody3D:
			body.velocity = Vector3.ZERO
	if _prompt:
		_prompt.visible = true
		_prompt.text = "Hit by dart! Sent back."
