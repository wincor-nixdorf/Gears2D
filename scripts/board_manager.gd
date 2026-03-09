# board_manager.gd
class_name BoardManager
extends RefCounted

var board: Node2D
var cells: Array = []  # двумерный массив клеток

func _init(p_board: Node2D):
	board = p_board
	# Предполагаем, что у board есть переменная cells
	cells = board.cells

# Получить клетку по координатам
func get_cell(pos: Vector2i) -> Cell:
	if pos.x < 0 or pos.x >= cells.size() or pos.y < 0 or pos.y >= cells[0].size():
		return null
	return cells[pos.x][pos.y]

# Проверить, пуста ли клетка
func is_cell_empty(pos: Vector2i) -> bool:
	var cell = get_cell(pos)
	return cell == null or cell.is_empty()

# Получить шестерню на клетке (если есть)
func get_gear_at(pos: Vector2i) -> Gear:
	var cell = get_cell(pos)
	if cell:
		return cell.occupied_gear
	return null

# Разместить шестерню на клетке
func place_gear(gear: Gear, pos: Vector2i) -> bool:
	var cell = get_cell(pos)
	if not cell or not cell.is_empty():
		return false
	cell.set_occupied(gear)
	gear.board_position = pos
	return true

# Убрать шестерню с клетки (не уничтожая)
func clear_gear(pos: Vector2i) -> void:
	var cell = get_cell(pos)
	if cell and cell.occupied_gear:
		cell.occupied_gear = null

# Получить все клетки доски
func get_all_cells() -> Array[Cell]:
	var all: Array[Cell] = []
	for row in cells:
		for cell in row:
			all.append(cell)
	return all

# Получить все шестерни на доске
func get_all_gears() -> Array[Gear]:
	var gears: Array[Gear] = []
	for row in cells:
		for cell in row:
			if cell.occupied_gear:
				gears.append(cell.occupied_gear)
	return gears

# Получить соседние клетки (ортогонально)
func get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in dirs:
		var n = pos + d
		if get_cell(n) != null:
			neighbors.append(n)
	return neighbors

# Проверить цвет клетки (true = белая, false = чёрная)
func is_white(pos: Vector2i) -> bool:
	return Game.is_cell_white(pos)

# Подсветить заданные клетки (предварительно сбрасывая подсветку)
func highlight_cells(cells_to_highlight: Array[Cell], color: Color = Color.YELLOW):
	reset_highlights()
	for cell in cells_to_highlight:
		cell.sprite.modulate = color

# Сбросить цвета клеток к стандартным
func reset_highlights():
	for row in cells:
		for cell in row:
			if cell.is_white():
				cell.sprite.modulate = Color(1, 1, 1, 0.8)
			else:
				cell.sprite.modulate = Color(0.2, 0.2, 0.2, 0.8)

# Включить/выключить жёлтую рамку подсветки
func set_cell_highlighted(pos: Vector2i, highlighted: bool):
	var cell = get_cell(pos)
	if cell:
		cell.set_highlighted(highlighted)

# Включить/выключить красную рамку активной клетки
func set_cell_active(pos: Vector2i, active: bool):
	var cell = get_cell(pos)
	if cell:
		cell.set_active(active)

# Получить стартовые позиции для игрока (для первого раунда)
func get_start_positions_for_player(player: int) -> Array[Vector2i]:
	if player == 0:
		return [Vector2i(3,4), Vector2i(4,3)]   # d5, e4
	else:
		return [Vector2i(3,3), Vector2i(4,4)]   # d4, e5
