extends Node3D

@export var door_path: NodePath
@export var one_shot := true

var _triggered := false

@onready var _area: Area3D = $Area3D


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _triggered and one_shot:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	var door := get_node_or_null(door_path)
	if door and door.has_method("unlock"):
		door.unlock()
