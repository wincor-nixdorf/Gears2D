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

func is_valid_start_position(pos: Vector2i) -> bool:
	if game_state.round_number == 1:
		var start_positions = get_start_positions_for_player(game_state.active_player_id)
		return pos in start_positions
	
	var has_enemy_gear = false
	for gear in board_manager.get_all_gears():
		if gear.owner_id != game_state.active_player_id:
			has_enemy_gear = true
			break
	
	if not has_enemy_gear:
		var is_white = board_manager.is_white(pos)
		var color_ok = (game_state.active_player_id == 0 and is_white) or (game_state.active_player_id == 1 and not is_white)
		var empty = board_manager.is_cell_empty(pos)
		return color_ok and empty
	
	for gear in board_manager.get_all_gears():
		if gear.owner_id != game_state.active_player_id:
			var enemy_pos = gear.board_position
			if pos in board_manager.get_neighbors(enemy_pos):
				var is_white = board_manager.is_white(pos)
				var color_ok = (game_state.active_player_id == 0 and is_white) or (game_state.active_player_id == 1 and not is_white)
				var empty = board_manager.is_cell_empty(pos)
				return color_ok and empty
	return false

func is_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	return abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y) == 1

func can_pass() -> bool:
	return not game_state.has_placed_this_turn and game_state.moves_in_round >= 2

func get_available_cells() -> Array[Cell]:
	var result: Array[Cell] = []
	if game_state.last_cell_pos == Vector2i(-1, -1):
		if game_state.round_number == 1:
			var start_positions = get_start_positions_for_player(game_state.active_player_id)
			for pos in start_positions:
				var cell = board_manager.get_cell(pos)
				if cell and cell.is_empty():
					result.append(cell)
		else:
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
				for cell in board_manager.get_all_cells():
					if cell.is_empty():
						if (game_state.active_player_id == 0 and cell.is_white()) or (game_state.active_player_id == 1 and cell.is_black()):
							result.append(cell)
		return result
	
	var neighbors = board_manager.get_neighbors(game_state.last_cell_pos)
	for n in neighbors:
		var cell = board_manager.get_cell(n)
		if not cell:
			continue
		var color_ok = (game_state.active_player_id == 0 and cell.is_white()) or (game_state.active_player_id == 1 and cell.is_black())
		if not color_ok:
			continue
		if cell.is_empty():
			result.append(cell)
			continue
		if cell.occupied_gear.is_owned_by(game_state.active_player_id):
			var has_direct_edge = game_state.chain_graph.has_edge(game_state.last_cell_pos, n)
			if not has_direct_edge:
				result.append(cell)
	return result

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
