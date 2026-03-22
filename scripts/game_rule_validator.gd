# game_rule_validator.gd
class_name GameRuleValidator
extends RefCounted

var game_manager: GameManager
var game_state: GameState
var board_manager: BoardManager

func _init(gm: GameManager, gs: GameState, bm: BoardManager):
	game_manager = gm
	game_state = gs
	board_manager = bm

# Проверка, можно ли начать цепочку с данной клетки
func is_valid_start_position(pos: Vector2i) -> bool:
	# Если на доске нет шестерен, разрешены только стартовые позиции для текущего игрока
	if board_manager.get_all_gears().is_empty():
		var start_positions = get_start_positions_for_player(game_state.active_player_id)
		return pos in start_positions
	
	# Если есть вражеские шестерни, можно начинать только с соседних с ними клеток
	var has_enemy_gear = false
	for gear in board_manager.get_all_gears():
		if gear.owner_id != game_state.active_player_id:
			has_enemy_gear = true
			break
	
	if not has_enemy_gear:
		# Нет вражеских шестерен – можно ставить на любую пустую клетку своего цвета
		var is_white = board_manager.is_white(pos)
		var color_ok = (game_state.active_player_id == 0 and is_white) or (game_state.active_player_id == 1 and not is_white)
		var empty = board_manager.is_cell_empty(pos)
		return color_ok and empty
	
	# Проверяем соседство с вражескими шестернями
	for gear in board_manager.get_all_gears():
		if gear.owner_id != game_state.active_player_id:
			var enemy_pos = gear.board_position
			if pos in board_manager.get_neighbors(enemy_pos):
				var is_white = board_manager.is_white(pos)
				var color_ok = (game_state.active_player_id == 0 and is_white) or (game_state.active_player_id == 1 and not is_white)
				var empty = board_manager.is_cell_empty(pos)
				return color_ok and empty
	return false

# Проверка ортогональной смежности
func is_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	return abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y) == 1

# Проверка возможности паса (всегда true в фазе построения цепочки)
func can_pass() -> bool:
	return game_state.current_phase == Game.GamePhase.CHAIN_BUILDING

# Возвращает список клеток, доступных для хода в текущий момент
func get_available_cells() -> Array[Cell]:
	var result: Array[Cell] = []
	GameLogger.debug("get_available_cells: last_cell_pos = %s, phase = %s" % [game_state.last_cell_pos, game_state.current_phase])
	
	# Если цепочка ещё не начата (last_cell_pos == -1)
	if game_state.last_cell_pos == Vector2i(-1, -1):
		# Проверяем, есть ли хоть одна шестерня на доске
		var any_gear_on_board = not board_manager.get_all_gears().is_empty()
		GameLogger.debug("get_available_cells: any_gear_on_board = %s, active_player = %d" % [any_gear_on_board, game_state.active_player_id])
		
		if not any_gear_on_board:
			# Доска пуста – только стартовые позиции для текущего игрока
			var start_positions = get_start_positions_for_player(game_state.active_player_id)
			GameLogger.debug("get_available_cells: board empty, start positions: %s" % str(start_positions))
			for pos in start_positions:
				var cell = board_manager.get_cell(pos)
				if cell and cell.is_empty():
					result.append(cell)
			GameLogger.debug("get_available_cells: returning %d cells" % result.size())
			return result
		else:
			# На доске есть шестерни, но цепочка не начата
			var has_enemy_gear = false
			for gear in board_manager.get_all_gears():
				if gear.owner_id != game_state.active_player_id:
					has_enemy_gear = true
					break
			if has_enemy_gear:
				var candidates: Array[Cell] = []
				for gear in board_manager.get_all_gears():
					if gear.owner_id != game_state.active_player_id:
						var enemy_pos = gear.board_position
						for n in board_manager.get_neighbors(enemy_pos):
							var cell = board_manager.get_cell(n)
							if cell and cell.is_empty():
								if (game_state.active_player_id == 0 and cell.is_white()) or (game_state.active_player_id == 1 and cell.is_black()):
									if not cell in candidates:
										candidates.append(cell)
				result = candidates
			else:
				# Вражеских шестерен нет – можно ставить на любую пустую клетку своего цвета
				for cell in board_manager.get_all_cells():
					if cell.is_empty():
						if (game_state.active_player_id == 0 and cell.is_white()) or (game_state.active_player_id == 1 and cell.is_black()):
							result.append(cell)
			GameLogger.debug("get_available_cells: returning %d cells (board has gears)" % result.size())
			return result
	
	# Цепочка уже начата – доступны соседние клетки, удовлетворяющие правилам
	var neighbors = board_manager.get_neighbors(game_state.last_cell_pos)
	for n in neighbors:
		var cell = board_manager.get_cell(n)
		if not cell:
			continue
		# Проверка цвета клетки (для текущего активного игрока)
		var color_ok = (game_state.active_player_id == 0 and cell.is_white()) or (game_state.active_player_id == 1 and cell.is_black())
		if not color_ok:
			continue
		# Пустая клетка – подходит
		if cell.is_empty():
			result.append(cell)
			continue
		# Занятая клетка – можно использовать только свою шестерню, если ещё нет прямого ребра
		if cell.occupied_gear and cell.occupied_gear.is_owned_by(game_state.active_player_id):
			var has_direct_edge = game_state.chain_graph.has_edge(game_state.last_cell_pos, n)
			if not has_direct_edge:
				result.append(cell)
	GameLogger.debug("get_available_cells: returning %d cells (chain in progress)" % result.size())
	return result

# Возвращает стартовые позиции для заданного игрока (для первого хода в раунде)
func get_start_positions_for_player(player: int) -> Array[Vector2i]:
	return board_manager.get_start_positions_for_player(player)

# --- Методы для перемещения существ ---

# Проверяет, свободен ли путь по диагонали/прямой для перемещения как король
# Все промежуточные клетки должны быть пустыми и того же цвета, что и стартовая
func is_path_clear_for_king(start: Vector2i, target: Vector2i, player_color_is_white: bool) -> bool:
	var dx = sign(target.x - start.x)
	var dy = sign(target.y - start.y)
	var steps = max(abs(target.x - start.x), abs(target.y - start.y))
	var current = start + Vector2i(dx, dy)
	for i in range(steps - 1):
		var cell = board_manager.get_cell(current)
		if not cell or not cell.is_empty():
			return false
		if cell.is_white() != player_color_is_white:
			return false
		current += Vector2i(dx, dy)
	return true

# Возвращает все пустые клетки своего цвета, достижимые существом за его speed,
# с учётом flying (для нелетающих проверяем путь)
func get_reachable_cells_for_creature(creature: Gear, from_pos: Vector2i, last_cell_pos: Vector2i) -> Array[Cell]:
	var result: Array[Cell] = []
	var speed = creature.speed
	var from_cell = board_manager.get_cell(from_pos)
	if not from_cell:
		return result
	var player_color_is_white = (creature.owner_id == 0)  # цвет игрока, которому принадлежит существо
	var is_white = from_cell.is_white()
	
	for x in range(Game.BOARD_SIZE):
		for y in range(Game.BOARD_SIZE):
			var pos = Vector2i(x, y)
			if pos == from_pos:
				continue
			var cell = board_manager.get_cell(pos)
			if not cell or not cell.is_empty():
				continue
			if cell.is_white() != is_white:
				continue
			var dx = abs(pos.x - from_pos.x)
			var dy = abs(pos.y - from_pos.y)
			var distance = max(dx, dy)
			if distance > speed:
				continue
			if not creature.is_flying:
				if not is_path_clear_for_king(from_pos, pos, player_color_is_white):
					continue
			result.append(cell)
	return result
