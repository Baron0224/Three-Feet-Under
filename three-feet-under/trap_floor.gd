extends Node3D

@export var respawn_path: NodePath
@export var prompt_path: NodePath = NodePath("../HUD/InteractPrompt")
@export var open_degrees := 110.0
@export var open_speed := 120.0
@export var fall_respawn_delay := 1.4
@export var pit_y := -1.5

var _triggered := false
var _opening := false
var _open_t := 0.0
var _player: Node3D

@onready var _trigger: Area3D = $TriggerArea
@onready var _left: Node3D = $LeftPanel
@onready var _right: Node3D = $RightPanel
@onready var _left_body: StaticBody3D = $LeftPanel/StaticBody3D
@onready var _right_body: StaticBody3D = $RightPanel/StaticBody3D
@onready var _spike_area: Area3D = $Pit/SpikeArea
@onready var _prompt: Label = get_node_or_null(prompt_path)


func _ready() -> void:
	_trigger.body_entered.connect(_on_trigger_entered)
	_spike_area.body_entered.connect(_on_spike_entered)


func _on_trigger_entered(body: Node) -> void:
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	_opening = true
	_player = body
	if _prompt:
		_prompt.visible = true
		_prompt.text = "Floor opens!"


func _on_spike_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_respawn(body)


func _process(delta: float) -> void:
	if _opening:
		_open_t = move_toward(_open_t, 1.0, (open_speed / open_degrees) * delta)
		var ang := deg_to_rad(open_degrees * _open_t)
		_left.rotation.z = -ang
		_right.rotation.z = ang
		if _open_t >= 1.0:
			_opening = false
			_left_body.collision_layer = 0
			_left_body.collision_mask = 0
			_right_body.collision_layer = 0
			_right_body.collision_mask = 0
			if _player:
				_fall_and_respawn(_player)

	if _player and is_instance_valid(_player) and _triggered:
		if _player.global_position.y < global_position.y + pit_y:
			_respawn(_player)


func _fall_and_respawn(body: Node) -> void:
	await get_tree().create_timer(fall_respawn_delay).timeout
	if is_instance_valid(body):
		_respawn(body)


func _respawn(body: Node) -> void:
	var marker := get_node_or_null(respawn_path)
	if marker and body is Node3D:
		body.global_position = marker.global_position
		if body is CharacterBody3D:
			body.velocity = Vector3.ZERO
	if _prompt:
		_prompt.visible = true
		_prompt.text = "Spikes! Sent back."
		await get_tree().create_timer(1.2).timeout
		if _prompt:
			_prompt.visible = false
