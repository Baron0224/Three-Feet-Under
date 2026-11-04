extends MeshInstance3D

@export var read_distance: float = 2.0
@export var leave_distance: float = 2.2

@onready var player: Node3D = $"../player"
@onready var prompt: Label = $"../HUD/InteractPrompt"

var can_read := false
var reading := false


func _ready() -> void:
	prompt.visible = false


func _process(_delta: float) -> void:
	# 按地面上的距离判断靠近，不受玩家转头和眼睛高度影响。
	var offset := player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()

	# 离开范围稍大，避免站在边界时提示反复闪烁。
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
				if reading or can_read:
					reading = not reading
					get_viewport().set_input_as_handled()