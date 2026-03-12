extends Node

# Константы игры
const CELL_SIZE = 100
const CELL_INDENT = 0.9
const BOARD_SIZE = 8
const MAX_DAMAGE = 24
const START_HAND_SIZE = 6
const DECK_SIZE = 32

# Перечисление фаз игры
enum GamePhase {
	CHAIN_BUILDING,
	UPTURN,
	CHAIN_RESOLUTION,
	RENEWAL
}

# Вспомогательные функции

# Проверка, является ли клетка белой (по шахматной раскраске)
static func is_cell_white(pos: Vector2i) -> bool:
	return (pos.x + pos.y) % 2 == 1

# Преобразование координат клетки в шахматную нотацию (например, a1, h8)
static func pos_to_chess(pos: Vector2i) -> String:
	var letters = ["a", "b", "c", "d", "e", "f", "g", "h"]
	return letters[pos.x] + str(pos.y + 1)
