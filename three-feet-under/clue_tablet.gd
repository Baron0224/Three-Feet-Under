extends MeshInstance3D

const TABLET_SCRAPE := preload("res://audio/sfx/footstep/footstep_stone_1.ogg")

@export var read_distance: float = 2.0
@export var leave_distance: float = 2.2
@export var door_path: NodePath = NodePath("../Door")

@onready var player: Node3D = $"../player"
@onready var prompt: Label = $"../HUD/InteractPrompt"

var can_read := false
var reading := false
var _door_unlocked := false
var _sfx: AudioStreamPlayer3D


func _ready() -> void:
	prompt.visible = false
	_sfx = AudioStreamPlayer3D.new()
	_sfx.stream = TABLET_SCRAPE
	_sfx.volume_db = -4.0
	_sfx.max_distance = 8.0
	add_child(_sfx)


func _process(_delta: float) -> void:
	if not player.can_interact():
		close_reading()
		return
	var door := get_node_or_null(door_path)
	# Near the door: let the door script own the prompt.
	if not reading and door and door.has_method("is_player_near") and door.is_player_near():
		return
	# Ground-plane distance so looking up/down does not change near range.
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


func close_reading() -> void:
	reading = false
	can_read = false
	player.set_reading(false)
	prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not player.can_interact():
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		var door := get_node_or_null(door_path)
		if not reading and door and door.has_method("is_player_near") and door.is_player_near():
			return
		if reading or can_read:
			reading = not reading
			player.set_reading(reading)
			# Stone scrape: deep slow pitch when opening, shorter when closing.
			if _sfx:
				_sfx.pitch_scale = 0.55 if reading else 0.85
				_sfx.play()
			if reading and not _door_unlocked:
				_unlock_door()
			get_viewport().set_input_as_handled()


func _unlock_door() -> void:
	var door := get_node_or_null(door_path)
	if door and door.has_method("unlock"):
		door.unlock()
		_door_unlocked = true
