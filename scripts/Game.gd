# Game.gd
extends Node

# Константы игры
const CELL_SIZE = 100
const CELL_INDENT = 0.9
const BOARD_SIZE = 8
const MAX_DAMAGE = 24
const START_HAND_SIZE = 6
const DECK_SIZE = 32
const MAX_HAND_SIZE = 6

# Перечисление фаз игры (в хронологическом порядке)
enum GamePhase {
	# Beginning Phase (Начальная фаза)
	UPKEEP,             # 0 - Шаг обслуживания
	DRAW,               # 1 - Шаг взятия карты
	
	# Main Phase (Основная фаза)
	CHAIN_BUILDING,     # 2 - Фаза построения цепочки
	
	# Pre-resolution Phase (Фаза перед разрешением)
	SWING_BACK,         # 3 - Фаза замаха
	
	# Resolution Phase (Фаза разрешения)
	CHAIN_RESOLUTION,   # 4 - Фаза разрешения цепочки
	
	# Ending Phase (Финальная фаза)
	END,                # 5 - Шаг конца хода
	CLEANUP             # 6 - Шаг очистки
}

# Вспомогательные функции

# Проверка, является ли клетка белой (по шахматной раскраске)
static func is_cell_white(pos: Vector2i) -> bool:
	return (pos.x + pos.y) % 2 == 1

# Преобразование координат клетки в шахматную нотацию (например, a1, h8)
static func pos_to_chess(pos: Vector2i) -> String:
	var letters = ["a", "b", "c", "d", "e", "f", "g", "h"]
	return letters[pos.x] + str(pos.y + 1)
