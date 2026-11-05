extends Node3D

@export var open_distance := 2.0
@export var open_amount := 2.5
@export var open_speed := 2.0
## 1 = 往右开，-1 = 往左开
@export var open_side := 1.0
@export var prompt_path: NodePath = NodePath("../HUD/InteractPrompt")
@export var auto_open_on_unlock := true

var _unlocked := false
var _opening := false
var _opened := false
var _start_x := 0.0
var _player: Node3D

@onready var _body: StaticBody3D = $StaticBody3D
@onready var _prompt: Label = get_node_or_null(prompt_path)


func _ready() -> void:
	_start_x = position.x
	_player = get_tree().get_first_node_in_group("player")


func unlock() -> void:
	_unlocked = true
	if auto_open_on_unlock and not _opened and not _opening:
		_opening = true
		if _prompt:
			_prompt.visible = false


func is_player_near() -> bool:
	if _player == null:
		return false
	return global_position.distance_to(_player.global_position) <= open_distance


func _process(delta: float) -> void:
	if _opening:
		var target_x := _start_x + open_side * open_amount
		position.x = move_toward(position.x, target_x, open_speed * delta)
		if is_equal_approx(position.x, target_x):
			_opening = false
			_opened = true
			if _body:
				_body.collision_layer = 0
				_body.collision_mask = 0
		return

	if _opened:
		return

	if is_player_near() and _prompt and not _unlocked:
		_prompt.visible = true
		_prompt.text = "似乎需要先触发机关"
