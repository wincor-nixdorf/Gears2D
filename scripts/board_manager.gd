# board_manager.gd
class_name BoardManager
extends RefCounted

var board: Node2D
var cells: Array = []  # двумерный массив клеток

func _init(p_board: Node2D) -> void:
	board = p_board
	cells = board.cells

# Возвращает клетку по координатам, или null, если координаты вне доски
func get_cell(pos: Vector2i) -> Cell:
	if pos.x < 0 or pos.x >= cells.size() or pos.y < 0 or pos.y >= cells[0].size():
		return null
	return cells[pos.x][pos.y]

# Проверяет, пуста ли клетка
func is_cell_empty(pos: Vector2i) -> bool:
	var cell = get_cell(pos)
	return cell == null or cell.is_empty()

# Возвращает шестерню на клетке (если есть)
func get_gear_at(pos: Vector2i) -> Gear:
	var cell = get_cell(pos)
	if cell:
		return cell.occupied_gear
	return null

# Размещает шестерню на клетке. Возвращает true при успехе.
func place_gear(gear: Gear, pos: Vector2i) -> bool:
	var cell = get_cell(pos)
	if not cell or not cell.is_empty():
		return false
	cell.set_occupied(gear)
	gear.board_position = pos
	gear.zone = Gear.Zone.BOARD   # устанавливаем зону
	return true

# Убирает шестерню с клетки (не уничтожая)
func clear_gear(pos: Vector2i) -> void:
	var cell = get_cell(pos)
	if cell and cell.occupied_gear:
		cell.occupied_gear = null

# Возвращает массив всех клеток доски
func get_all_cells() -> Array[Cell]:
	var all: Array[Cell] = []
	for row in cells:
		for cell in row:
			all.append(cell)
	return all

# Возвращает массив всех шестерней на доске
func get_all_gears() -> Array[Gear]:
	var gears: Array[Gear] = []
	for row in cells:
		for cell in row:
			if cell.occupied_gear:
				gears.append(cell.occupied_gear)
	return gears

# Возвращает массив координат соседних клеток (ортогонально)
func get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in dirs:
		var n = pos + d
		if get_cell(n) != null:
			neighbors.append(n)
	return neighbors

# Проверяет, является ли клетка белой
func is_white(pos: Vector2i) -> bool:
	return Game.is_cell_white(pos)

# Подсвечивает заданные клетки (предварительно сбрасывая подсветку)
func highlight_cells(cells_to_highlight: Array[Cell], color: Color = Color.YELLOW) -> void:
	reset_highlights()
	for cell in cells_to_highlight:
		cell.sprite.modulate = color

# Сбрасывает цвета клеток к стандартным
func reset_highlights() -> void:
	for row in cells:
		for cell in row:
			if cell.is_white():
				cell.sprite.modulate = Color(1, 1, 1, 0.8)
			else:
				cell.sprite.modulate = Color(0.2, 0.2, 0.2, 0.8)

# Включает/выключает жёлтую рамку подсветки для клетки
func set_cell_highlighted(pos: Vector2i, highlighted: bool) -> void:
	var cell = get_cell(pos)
	if cell:
		cell.set_highlighted(highlighted)

# Включает/выключает красную рамку активной клетки
func set_cell_active(pos: Vector2i, active: bool) -> void:
	var cell = get_cell(pos)
	if cell:
		cell.set_active(active)

# Сбрасывает жёлтую подсветку для всех клеток (рамки)
func reset_chain_highlights() -> void:
	for row in cells:
		for cell in row:
			cell.set_highlighted(false)

# Возвращает стартовые позиции для игрока (для первого раунда)
func get_start_positions_for_player(player: int) -> Array[Vector2i]:
	if player == 0:
		return [Vector2i(3,4), Vector2i(4,3)]   # d5, e4
	else:
		return [Vector2i(3,3), Vector2i(4,4)]   # d4, e5
