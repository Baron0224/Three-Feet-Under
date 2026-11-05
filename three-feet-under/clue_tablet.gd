extends MeshInstance3D

@export var read_distance: float = 2.0
@export var leave_distance: float = 2.2
@export var door_path: NodePath = NodePath("../Door")

@onready var player: Node3D = $"../player"
@onready var prompt: Label = $"../HUD/InteractPrompt"

var can_read := false
var reading := false
var _door_unlocked := false


func _ready() -> void:
	prompt.visible = false


func _process(_delta: float) -> void:
	var door := get_node_or_null(door_path)
	# 靠近门时，把提示交给门脚本
	if not reading and door and door.has_method("is_player_near") and door.is_player_near():
		return

	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()

	if can_read:
		can_read = distance <= maxf(read_distance, leave_distance)
	else:
		can_read = distance <= read_distance

	if reading:
		prompt.visible = true
		prompt.text = (
			"石板上刻着几行模糊的字：\n"
			+ "“循旧痕而入，勿信眼前之路。”\n\n"
			+ "按 E 关闭"
		)
	else:
		prompt.visible = can_read
		prompt.text = "按 E 阅读石板"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.physical_keycode == KEY_E:
				var door := get_node_or_null(door_path)
				if not reading and door and door.has_method("is_player_near") and door.is_player_near():
					return
				if reading or can_read:
					reading = not reading
					if reading and not _door_unlocked:
						_unlock_door()
					get_viewport().set_input_as_handled()


func _unlock_door() -> void:
	var door := get_node_or_null(door_path)
	if door and door.has_method("unlock"):
		door.unlock()
		_door_unlocked = true
