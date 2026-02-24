extends Node2D

const CELL_SIZE = 64
const CELL_INDENT = 0.9
const BOARD_SIZE = 8
const BOARD_SHIFT_X = 100
const BOARD_SHIFT_Y = 100
const GEAR_TEXTURE_SIZE = 509  # замените на реальный размер вашей текстуры

var cells: Array = []  # двумерный массив ссылок на клетки
var current_gear_scene: PackedScene = preload("res://scenes/Gear.tscn")

func _ready():
	generate_board()

func generate_board():
	for x in range(BOARD_SIZE):
		var row = []
		for y in range(BOARD_SIZE):
			var cell = preload("res://scenes/Cell.tscn").instantiate()
			add_child(cell)
			cell.position = Vector2(x * CELL_SIZE + BOARD_SHIFT_X, y * CELL_SIZE + BOARD_SHIFT_Y)
			cell.board_pos = Vector2i(x, y)
			# Шахматная раскраска: (x+y) чётное – белое (игрок 1), нечётное – чёрное (игрок 2)
			if (x + y) % 2 == 0:
				cell.sprite.modulate = Color(1, 1, 1, 0.8)  # белое с прозрачностью
			else:
				cell.sprite.modulate = Color(0.2, 0.2, 0.2, 0.8)  # тёмно-серое (чёрное)
			cell.clicked.connect(_on_cell_clicked)
			row.append(cell)
		cells.append(row)


func _on_cell_clicked(cell: Node2D, board_pos: Vector2i):
	if not cell.is_empty():
		print("Клетка занята")
		return
	
	var new_gear = current_gear_scene.instantiate()
	
	# Устанавливаем текстуры (должны быть загружены до вызова set_cell_size)
	new_gear.texture_reverse = preload("res://assets/gears/revers.png")
	new_gear.texture_obverse = preload("res://assets/gears/obverse_bird_of_paradise.png")
	
	# Настраиваем размер под клетку (используем CELL_SIZE и отступ)
	new_gear.set_cell_size(CELL_SIZE, CELL_INDENT)
	
	# Прочие параметры
	new_gear.gear_name = "Test Gear"
	new_gear.owner_id = 0
	new_gear.max_good_ticks = 3
	new_gear.max_bad_ticks = 2
	
	# Размещаем на клетке
	cell.set_occupied(new_gear)
