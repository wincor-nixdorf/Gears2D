# board.gd
extends Node2D

const BOARD_SHIFT_X = 100
const BOARD_SHIFT_Y = 200
const CELL_SCENE = preload("res://scenes/Cell.tscn")

var cells: Array = []   # двумерный массив клеток

func _ready():
	generate_board()

## Генерирует доску размером Game.BOARD_SIZE x Game.BOARD_SIZE.
func generate_board():
	# Удаляем старые клетки
	for child in get_children():
		child.queue_free()
	
	cells.clear()
	
	for x in range(Game.BOARD_SIZE):
		var row = []
		for y in range(Game.BOARD_SIZE):
			var cell = CELL_SCENE.instantiate()
			add_child(cell)
			cell.position = Vector2(x * Game.CELL_SIZE + BOARD_SHIFT_X, 
									(Game.BOARD_SIZE - 1 - y) * Game.CELL_SIZE + BOARD_SHIFT_Y)
			cell.board_pos = Vector2i(x, y)
			cell.set_highlight_size(Game.CELL_SIZE)
			# Устанавливаем цвет фона в зависимости от цвета клетки
			if cell.is_white():
				cell.sprite.modulate = Color(1, 1, 1, 0.8)
			else:
				cell.sprite.modulate = Color(0.2, 0.2, 0.2, 0.8)
			# Подключаем сигнал clicked — теперь он передаёт только клетку
			cell.clicked.connect(_on_cell_clicked)
			row.append(cell)
		cells.append(row)

## Обработчик клика по клетке (может быть переопределён в game_manager).
func _on_cell_clicked(cell: Cell):
	pass
