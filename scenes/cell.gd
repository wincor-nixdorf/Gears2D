extends Area2D

signal clicked(cell: Node2D, board_pos: Vector2i)

var board_pos: Vector2i
var occupied_gear: Node2D = null

@onready var sprite: Sprite2D = $Sprite

func _ready():
	# Цвет клетки будет задаваться из Board
	input_event.connect(_on_input_event)

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Клик по клетке ", board_pos)   # <-- добавить
		clicked.emit(self, board_pos)

func is_empty() -> bool:
	return occupied_gear == null

func set_occupied(gear: Node2D):
	occupied_gear = gear
	add_child(gear)
	gear.position = Vector2.ZERO  # центр клетки

func remove_gear():
	if occupied_gear:
		occupied_gear.queue_free()
		occupied_gear = null


func _on_clicked(cell, board_pos):
	pass # Replace with function body.
