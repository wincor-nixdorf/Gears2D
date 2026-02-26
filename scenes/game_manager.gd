# GameManager.gd
extends Node

@onready var board: Node2D = $Board
@onready var ui: UI = $UI

const MAX_DAMAGE = 50
const START_HAND_SIZE = 6
const DECK_SIZE = 32
const CELL_SIZE = 64
const CELL_INDENT = 0.9
const BOARD_SIZE = 8

enum GamePhase {
	CHAIN_BUILDING,
	UPTURN,
	CHAIN_RESOLUTION,
	RENEWAL
}

var current_phase: GamePhase = GamePhase.CHAIN_BUILDING
var active_player_id: int = 0
var round_number: int = 1

var players: Array[Player] = []
var chain_cells: Array[Cell] = []
var last_cell: Cell = null
var t_pool: Array[int] = [0, 0]
var passed: bool = false

var current_resolve_index: int = -1
var waiting_for_player: bool = false
var selected_gear: Node2D = null

# Флаг: поставил ли текущий игрок шестерёнку в этом ходу
var has_placed_this_turn: bool = false

const PLAYER_SCENE = preload("res://scenes/Player.tscn")

func _ready():
	initialize_game()
	ui.action_pressed.connect(_on_action_button_pressed)
	ui.hand_gear_selected.connect(_on_hand_gear_selected)

func initialize_game():
	var gear_scene = preload("res://scenes/Gear.tscn")
	var deck1: Array[PackedScene] = []
	var deck2: Array[PackedScene] = []
	for i in range(DECK_SIZE):
		deck1.append(gear_scene)
		deck2.append(gear_scene)
	
	var player1 = PLAYER_SCENE.instantiate()
	var player2 = PLAYER_SCENE.instantiate()
	
	player1.player_id = 0
	player1.owner_id = 0
	player1.deck = deck1
	player1.draw_starting_hand(START_HAND_SIZE)
	
	player2.player_id = 1
	player2.owner_id = 1
	player2.deck = deck2
	player2.draw_starting_hand(START_HAND_SIZE)
	
	add_child(player1)
	add_child(player2)
	players = [player1, player2]
	
	board.generate_board()
	
	print("Подключаем сигналы клеток...")
	for row in board.cells:
		for cell in row:
			cell.clicked.connect(_on_cell_clicked)
	print("Сигналы подключены")
	
	start_round()

func start_round():
	print("Раунд ", round_number, ". Активный игрок: ", active_player_id)
	chain_cells.clear()
	last_cell = null
	passed = false
	current_phase = GamePhase.CHAIN_BUILDING
	has_placed_this_turn = false
	selected_gear = null
	ui.clear_selection()
	update_ui()

func _on_cell_clicked(cell: Cell, board_pos: Vector2i):
	print("Клик по клетке ", board_pos, " фаза: ", current_phase)
	match current_phase:
		GamePhase.CHAIN_BUILDING:
			handle_chain_building_click(cell, board_pos)
		_:
			print("Клик проигнорирован – фаза ", current_phase)

func handle_chain_building_click(cell: Cell, board_pos: Vector2i):
	print("handle_chain_building_click: клетка ", board_pos)
	
	# Если игрок уже поставил в этом ходу, не даём ставить ещё
	if has_placed_this_turn:
		print("Вы уже поставили шестерёнку в этом ходу. Нажмите 'Конец хода'.")
		return
	
	# Если клетка занята, пробуем использовать существующую шестерёнку
	if not cell.is_empty():
		# Нельзя использовать занятую клетку на первом ходу
		if chain_cells.is_empty():
			print("Нельзя использовать занятую клетку на первом ходу")
			return
		if last_cell == null:
			return
		# Проверяем прилегание к последней клетке
		if not is_adjacent(last_cell.board_pos, board_pos):
			print("Не прилегает к последней клетке")
			return
		var gear = cell.occupied_gear
		if gear.owner_id != active_player_id:
			print("Это не ваша шестерёнка")
			return
		# Проверяем, не образует ли цикл (если клетка уже в цепочке)
		if cell in chain_cells:
			print("Образован цикл, цепочка завершается")
			end_chain_building()
			return
		# Добавляем существующую шестерёнку в цепочку
		chain_cells.append(cell)
		last_cell = cell
		# НЕ начисляем T за использование уже стоящей шестерёнки
		print("Использована существующая шестерёнка")
		has_placed_this_turn = true
		update_ui()
		return
	
	# Далее код для пустой клетки (новая шестерёнка)
	var is_white = (board_pos.x + board_pos.y) % 2 == 1
	var current_player = players[active_player_id]
	print("Проверка цвета: is_white=", is_white, " owner=", current_player.owner_id)
	if current_player.owner_id == 0 and not is_white:
		print("Игрок 1 может ставить только на белые поля")
		return
	if current_player.owner_id == 1 and is_white:
		print("Игрок 2 может ставить только на чёрные поля")
		return
	
	if chain_cells.is_empty():
		print("Цепочка пуста, проверяем стартовые поля")
		var start_positions = get_start_positions_for_player(active_player_id)
		if board_pos not in start_positions:
			print("Не стартовое поле для текущего игрока")
			return
		if not place_gear_from_hand(cell, current_player):
			return
		chain_cells.append(cell)
		last_cell = cell
		t_pool[active_player_id] += 1
		print("Первый ход: установлена шестерёнка в ", board_pos, " получен T. Теперь T", active_player_id, " = ", t_pool[active_player_id])
		has_placed_this_turn = true
		update_ui()
		return
	
	if last_cell and not is_adjacent(last_cell.board_pos, board_pos):
		print("Не прилегает к последней клетке")
		return
	
	if not place_gear_from_hand(cell, current_player):
		return
	
	chain_cells.append(cell)
	last_cell = cell
	t_pool[active_player_id] += 1
	print("Установлена шестерёнка в цепочку, получен T. Теперь T", active_player_id, " = ", t_pool[active_player_id])
	has_placed_this_turn = true
	update_ui()

func is_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	return abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y) == 1

func place_gear_from_hand(cell: Cell, player: Player) -> bool:
	if not selected_gear:
		print("Нет выбранной шестерёнки")
		return false
	if selected_gear.owner_id != player.owner_id or not (selected_gear in player.hand):
		print("Выбрана не та шестерёнка")
		selected_gear = null
		ui.clear_selection()
		return false
	
	player.remove_from_hand(selected_gear)
	cell.set_occupied(selected_gear)
	print("Шестерёнка установлена в клетку ", cell.board_pos)
	
	selected_gear.set_cell_size(CELL_SIZE, CELL_INDENT)
	
	selected_gear.rotated.connect(_on_gear_rotated)
	selected_gear.triggered.connect(_on_gear_triggered)
	selected_gear.destroyed.connect(_on_gear_destroyed)
	selected_gear.clicked.connect(_on_gear_clicked)
	selected_gear.mouse_entered.connect(_on_gear_mouse_entered)
	selected_gear.mouse_exited.connect(_on_gear_mouse_exited)
	print("Сигналы мыши подключены для шестерёнки")
	
	selected_gear = null
	ui.clear_selection()
	return true

func _on_gear_rotated(gear: Node2D, old_ticks: int, new_ticks: int):
	pass

func _on_gear_triggered(gear: Node2D):
	gear.apply_effect()
	update_ui()

func _on_gear_destroyed(gear: Node2D):
	if chain_cells.has(gear.get_parent() as Cell):
		var cell = gear.get_parent() as Cell
		chain_cells.erase(cell)
		if last_cell == cell:
			last_cell = chain_cells.back() if not chain_cells.is_empty() else null
	update_ui()

func _on_gear_clicked(gear: Node2D):
	match current_phase:
		GamePhase.UPTURN:
			handle_upturn_gear_click(gear)
		GamePhase.CHAIN_RESOLUTION:
			handle_resolution_gear_click(gear)
		_:
			pass

func _on_gear_mouse_entered(gear: Node2D):
	print("GameManager: mouse_entered, gear.owner=", gear.owner_id, " active=", active_player_id)
	if gear.owner_id == active_player_id:
		print(" -> показываем тултип")
		ui.show_gear_tooltip(gear, get_viewport().get_mouse_position())
	else:
		print(" -> не показываем (не владелец)")

func _on_gear_mouse_exited(gear: Node2D):
	print("GameManager: mouse_exited")
	ui.hide_gear_tooltip()

func handle_upturn_gear_click(gear: Node2D):
	if gear.owner_id != active_player_id and not gear.is_face_up:
		if t_pool[active_player_id] > 0:
			t_pool[active_player_id] -= 1
			gear.show_obverse_temporarily()
			update_ui()
			print("Потрачен T на просмотр. Осталось T", active_player_id, ": ", t_pool[active_player_id])
		else:
			print("Недостаточно T для просмотра")
	else:
		print("Нельзя просмотреть свою или уже перевёрнутую шестерёнку")

func handle_resolution_gear_click(gear: Node2D):
	if not waiting_for_player:
		return
	var cell = chain_cells[current_resolve_index]
	if gear != cell.occupied_gear:
		print("Сейчас разрешается другая шестерёнка")
		return
	
	if gear.owner_id == active_player_id and t_pool[active_player_id] > 0:
		t_pool[active_player_id] -= 1
		gear.rotate_clockwise(1)
		update_ui()
		print("Дополнительный тик. Осталось T: ", t_pool[active_player_id])
	else:
		print("Недостаточно T или не ваша шестерёнка")

func _on_hand_gear_selected(gear: Node2D):
	if selected_gear:
		ui.unhighlight_gear(selected_gear)
	selected_gear = gear
	ui.highlight_gear(gear)

func end_chain_building():
	current_phase = GamePhase.UPTURN
	print("Фаза построения цепочки завершена. Начинается фаза upturn.")
	update_ui()

func end_upturn():
	current_phase = GamePhase.CHAIN_RESOLUTION
	print("Фаза upturn завершена. Начинается разрешение цепочки.")
	update_ui()
	start_chain_resolution()

func start_chain_resolution():
	if chain_cells.is_empty():
		end_chain_resolution()
		return
	current_resolve_index = chain_cells.size() - 1
	waiting_for_player = false
	resolve_current_gear()

func resolve_current_gear():
	if current_resolve_index < 0:
		end_chain_resolution()
		return
	
	var cell = chain_cells[current_resolve_index]
	var gear = cell.occupied_gear
	if not gear:
		current_resolve_index -= 1
		resolve_current_gear()
		return
	
	if gear.can_rotate():
		gear.rotate_clockwise(1)
		update_ui()
	
	waiting_for_player = true
	print("Ожидание действий игрока для шестерёнки на клетке ", cell.board_pos)

func end_chain_resolution():
	current_phase = GamePhase.RENEWAL
	print("Фаза разрешения цепочки завершена. Начинается renewal.")
	for i in [0,1]:
		var damage = t_pool[i]
		players[1-i].damage += damage
		t_pool[i] = 0
	for p in players:
		if p.damage >= MAX_DAMAGE:
			end_game(p.id)
			return
	for p in players:
		p.draw_card()
	active_player_id = 1 - active_player_id
	round_number += 1
	start_round()

func end_game(winner_id: int):
	print("Игрок ", winner_id, " победил!")
	get_tree().paused = true

func _on_action_button_pressed():
	match current_phase:
		GamePhase.CHAIN_BUILDING:
			if has_placed_this_turn:
				# Завершаем ход, переключаем игрока
				active_player_id = 1 - active_player_id
				has_placed_this_turn = false
				selected_gear = null
				ui.clear_selection()
				update_ui()
				print("Ход передан игроку ", active_player_id + 1)
			else:
				# Пас – завершаем фазу построения цепочки
				end_chain_building()
		GamePhase.UPTURN:
			end_upturn()
		GamePhase.CHAIN_RESOLUTION:
			if waiting_for_player:
				waiting_for_player = false
				current_resolve_index -= 1
				resolve_current_gear()
		GamePhase.RENEWAL:
			pass

func update_ui():
	ui.update_player(active_player_id)
	ui.update_phase(current_phase)
	ui.update_t_pool(t_pool[0], t_pool[1])
	ui.update_action_button(current_phase, has_placed_this_turn, active_player_id)
	ui.update_hands(players[0].hand, players[1].hand, active_player_id)
	highlight_available_cells()
	highlight_chain_cells()

# --- Подсветка доступных полей ---
func reset_cell_colors():
	for row in board.cells:
		for cell in row:
			var is_white = (cell.board_pos.x + cell.board_pos.y) % 2 == 1
			if is_white:
				cell.sprite.modulate = Color(1, 1, 1, 0.8)
			else:
				cell.sprite.modulate = Color(0.2, 0.2, 0.2, 0.8)

func highlight_available_cells():
	reset_cell_colors()
	if current_phase != GamePhase.CHAIN_BUILDING:
		return
	var available = get_available_cells()
	for cell in available:
		cell.sprite.modulate = Color.YELLOW

func get_available_cells() -> Array[Cell]:
	var result: Array[Cell] = []
	
	if chain_cells.is_empty():
		var start_positions = get_start_positions_for_player(active_player_id)
		for pos in start_positions:
			var cell = board.cells[pos.x][pos.y] as Cell
			if cell.is_empty():
				result.append(cell)
	else:
		var last = last_cell
		var neighbors = [
			Vector2i(last.board_pos.x + 1, last.board_pos.y),
			Vector2i(last.board_pos.x - 1, last.board_pos.y),
			Vector2i(last.board_pos.x, last.board_pos.y + 1),
			Vector2i(last.board_pos.x, last.board_pos.y - 1)
		]
		for n in neighbors:
			if n.x >= 0 and n.x < BOARD_SIZE and n.y >= 0 and n.y < BOARD_SIZE:
				var cell = board.cells[n.x][n.y] as Cell
				if cell.is_empty():
					var is_white = (n.x + n.y) % 2 == 1
					if (active_player_id == 0 and is_white) or (active_player_id == 1 and not is_white):
						result.append(cell)
	return result

func get_start_positions_for_player(player: int) -> Array[Vector2i]:
	if player == 0:  # белые
		return [Vector2i(3,4), Vector2i(4,3)]
	else:  # чёрные
		return [Vector2i(3,3), Vector2i(4,4)]

func highlight_chain_cells():
	for row in board.cells:
		for cell in row:
			cell.set_highlighted(false)
	for cell in chain_cells:
		cell.set_highlighted(true)
