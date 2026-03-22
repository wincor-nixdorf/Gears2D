# phase.gd
class_name Phase
extends RefCounted

var game_manager: GameManager
var game_state: GameState
var board_manager: BoardManager
var ui: UI
var players: Array

func _init(gm: GameManager, gs: GameState) -> void:
	game_manager = gm
	game_state = gs
	board_manager = gm.board_manager
	ui = gm.ui  # Сохраняем ссылку на UI
	players = gm.players

# Вызывается при входе в фазу
func enter() -> void:
	pass

# Вызывается при выходе из фазы
func exit() -> void:
	pass

# Обработка клика по клетке
func handle_cell_clicked(cell: Cell) -> void:
	pass

# Обработка клика по шестерне
func handle_gear_clicked(gear: Gear, button_index: int) -> void:
	pass

# Обработка клика по игроку
func handle_player_clicked(player: Player) -> void:
	pass

# Обработка нажатия на кнопку действия
func handle_action_button() -> void:
	pass

# Опционально: обновление каждый кадр
func update(delta: float) -> void:
	pass
