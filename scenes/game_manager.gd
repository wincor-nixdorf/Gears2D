# game_manager.gd
# Главный управляющий класс игры.
# Отвечает за логику игрового процесса, управление фазами,
# обработку действий игроков и взаимодействие с доской и UI.
extends Node

# Ссылки на основные узлы сцены (инжектируются через @onready)
@onready var board: Node2D = $Board          # Доска с клетками
@onready var ui: UI = $UI                     # Пользовательский интерфейс

# Предзагрузка сцен игроков и шестерёнок
const PLAYER_SCENE = preload("res://scenes/Player.tscn")
const GEAR_SCENE = preload("res://scenes/Gear.tscn")

# -------------------- Состояние игры --------------------
# Текущая фаза игры (Chain Building, Upturn, Chain Resolution, Renewal)
var current_phase: Game.GamePhase = Game.GamePhase.CHAIN_BUILDING
# ID активного игрока (0 - первый, 1 - второй)
var active_player_id: int = 0
# Номер текущего раунда
var round_number: int = 1
# Игрок, который начал текущий раунд (нужен для определения следующего активного после Renewal)
var start_player_id: int = 0

# Массив игроков (объекты Player)
var players: Array[Player] = []
# Пул ресурсов T для каждого игрока: t_pool[0] - T игрока 1, t_pool[1] - T игрока 2
var t_pool: Array[int] = [0, 0]
# Флаг паса (в текущей реализации не используется, но может пригодиться)
var passed: bool = false

# -------------------- Переменные для построения цепочки --------------------
# Граф цепочки: ключ - позиция клетки (Vector2i), значение - словарь соседних позиций с индексами рёбер
var chain_graph: Dictionary = {}
# Позиция последней клетки в текущей цепочке (Vector2i(-1,-1) если цепочка пуста)
var last_cell_pos: Vector2i = Vector2i(-1, -1)
# Откуда пришли в последнюю клетку (для обработки уничтожения)
var last_from_pos: Vector2i = Vector2i(-1, -1)
# Счётчик для присвоения уникальных номеров рёбрам
var current_edge_index: int = 0
# Флаг, сделал ли текущий игрок ход в своём текущем "подходе"
var has_placed_this_turn: bool = false
# Сколько ходов (установок G) уже сделано в раунде (для определения возможности паса)
var moves_in_round: int = 0
# Шестерёнка, выбранная в руке для установки
var selected_gear: Node2D = null

# -------------------- Переменные для разрешения цепочки --------------------
# Позиция текущей разрешаемой шестерёнки
var current_resolve_pos: Vector2i = Vector2i(-1, -1)
# Индекс ребра, по которому пришли в текущую клетку (чтобы не возвращаться обратно)
var came_from_edge: int = -1
# Флаг, ожидаем ли мы действие игрока (дополнительный тик) при разрешении
var waiting_for_player: bool = false

# Добавляем переменную для хранения последней подсказки
var last_prompt: String = ""
# ------------------------------------------------------------------
# Инициализация игры
# ------------------------------------------------------------------
func _ready():
	initialize_game()
	# Подключаем сигналы от UI
	ui.action_pressed.connect(_on_action_button_pressed)
	ui.hand_gear_selected.connect(_on_hand_gear_selected)
	GameLogger.info("GameManager ready")

func initialize_game():
	# Создаём колоды для двух игроков (заполняем сценами шестерёнок)
	var deck1: Array[PackedScene] = []
	var deck2: Array[PackedScene] = []
	for i in range(Game.DECK_SIZE):
		deck1.append(GEAR_SCENE)
		deck2.append(GEAR_SCENE)
	
	# Создаём игроков
	var player1 = PLAYER_SCENE.instantiate()
	var player2 = PLAYER_SCENE.instantiate()
	
	player1.player_id = 0
	player1.owner_id = 0        # Владелец шестерёнок (совпадает с player_id для простоты)
	player1.deck = deck1
	player1.draw_starting_hand(Game.START_HAND_SIZE)   # Раздаём стартовую руку
	
	player2.player_id = 1
	player2.owner_id = 1
	player2.deck = deck2
	player2.draw_starting_hand(Game.START_HAND_SIZE)
	
	add_child(player1)
	add_child(player2)
	players = [player1, player2]
	
	# Генерируем доску
	board.generate_board()
	
	# Подключаем сигнал клика по клетке для всех клеток
	for row in board.cells:
		for cell in row:
			cell.clicked.connect(_on_cell_clicked)
	
	# Запускаем первый раунд
	start_round()
	GameLogger.info("Game initialized")

# ------------------------------------------------------------------
# Управление раундами
# ------------------------------------------------------------------
func start_round():
	start_player_id = active_player_id      # Запоминаем, кто начал раунд
	GameLogger.info("=== Round %d. Active player: %d ===" % [round_number, active_player_id + 1])
	# Сбрасываем все переменные для нового раунда
	chain_graph.clear()
	last_cell_pos = Vector2i(-1, -1)
	last_from_pos = Vector2i(-1, -1)
	current_edge_index = 0
	passed = false
	current_phase = Game.GamePhase.CHAIN_BUILDING
	has_placed_this_turn = false
	moves_in_round = 0
	selected_gear = null
	ui.clear_selection()          # Убираем подсветку выбранной шестерёнки
	update_ui()                   # Обновляем интерфейс

# ------------------------------------------------------------------
# Обработка кликов по клеткам (в зависимости от фазы)
# ------------------------------------------------------------------
func _on_cell_clicked(cell: Cell):
	var board_pos = cell.board_pos
	GameLogger.debug("Click on cell %s (%s) phase: %s" % [str(board_pos), Game.pos_to_chess(board_pos), str(current_phase)])
	match current_phase:
		Game.GamePhase.CHAIN_BUILDING:
			handle_chain_building_click(cell)
		Game.GamePhase.CHAIN_RESOLUTION:
			# В фазе разрешения клики по пустым клеткам игнорируются (обрабатываются только клики по шестерёнкам)
			pass
		_:
			GameLogger.debug("Click ignored – phase %s" % current_phase)

# ------------------------------------------------------------------
# Логика фазы построения цепочки
# ------------------------------------------------------------------
func handle_chain_building_click(cell: Cell):
	var board_pos = cell.board_pos
	
	# 1. Проверка, что игрок ещё не сделал ход в этом подходе
	if has_placed_this_turn:
		GameLogger.warning("You have already made a move. Press 'End Turn' button to pass the turn.")
		return
	
	# 2. Проверка цвета клетки (каждый игрок ставит только на свои цвета)
	var is_white = cell.is_white()
	var current_player = players[active_player_id]
	if current_player.owner_id == 0 and not is_white:
		GameLogger.warning("Player 1 can only place on white cells")
		return
	if current_player.owner_id == 1 and is_white:
		GameLogger.warning("Player 2 can only place on black cells")
		return
	
	# 3. Если цепочка ещё не начата (last_cell_pos == -1)
	if last_cell_pos == Vector2i(-1, -1):
		if not is_valid_start_position(board_pos):
			GameLogger.warning("Cannot start chain from this cell")
			return
		if not cell.is_empty():
			GameLogger.warning("Starting cell must be empty")
			return
		# Пытаемся установить шестерёнку из руки
		if not place_gear_from_hand(cell, current_player):
			return
		# Начисляем T за установку новой G
		t_pool[active_player_id] += 1
		# Добавляем клетку в граф цепочки
		chain_graph[board_pos] = {}
		last_cell_pos = board_pos
		GameLogger.info("First move of the round: gear placed on %s. T = %d" % [Game.pos_to_chess(board_pos), t_pool[active_player_id]])
		on_successful_placement()
		return
	
	# 4. Цепочка уже начата: проверяем, прилегает ли выбранная клетка к последней
	if not is_adjacent(last_cell_pos, board_pos):
		GameLogger.warning("Cell is not adjacent to the last one")
		return
	
	# 5. Если клетка пустая – ставим новую G из руки
	if cell.is_empty():
		if not place_gear_from_hand(cell, current_player):
			return
		# Начисляем T за установку новой G
		t_pool[active_player_id] += 1
		# Добавляем ребро между последней и новой клеткой
		add_edge(last_cell_pos, board_pos)
		last_from_pos = last_cell_pos
		last_cell_pos = board_pos
		GameLogger.info("New gear placed on %s. T = %d" % [Game.pos_to_chess(board_pos), t_pool[active_player_id]])
		on_successful_placement()
		return
	
	# 6. Клетка занята – проверяем, чья это шестерёнка (используем метод is_owned_by)
	var gear = cell.occupied_gear
	if not gear.is_owned_by(active_player_id):
		GameLogger.warning("This is not your gear")
		return
	
	# 7. Проверяем, нет ли уже прямого ребра от последней клетки к этой (запрет цикла из двух)
	if chain_graph[last_cell_pos].has(board_pos):
		GameLogger.warning("Cannot create double connection (2-cycle)")
		return
	
	# 8. Если клетка уже есть в цепочке (кроме последней) – образуется допустимый цикл
	if chain_graph.has(board_pos):
		if board_pos == last_cell_pos:
			GameLogger.warning("Cannot use the same cell as the last one")
			return
		# Добавляем ребро, T не начисляем (используем существующую G)
		add_edge(last_cell_pos, board_pos)
		last_from_pos = last_cell_pos
		last_cell_pos = board_pos
		GameLogger.info("Cycle formed at %s. Chain building phase ends." % Game.pos_to_chess(board_pos))
		on_successful_placement()
		end_chain_building()   # Цикл автоматически завершает фазу построения
		return
	else:
		# 9. Клетка занята своей G, но ещё не в цепочке – добавляем как новую вершину (без начисления T)
		add_edge(last_cell_pos, board_pos)
		last_from_pos = last_cell_pos
		last_cell_pos = board_pos
		GameLogger.info("Existing gear on board used at %s" % Game.pos_to_chess(board_pos))
		on_successful_placement()
		return

# Функция, вызываемая после успешного хода (установки или задействования G)
func on_successful_placement():
	has_placed_this_turn = true
	moves_in_round += 1
	update_ui()

# Проверка, можно ли начинать цепочку с данной клетки (в зависимости от раунда и наличия вражеских G)
func is_valid_start_position(pos: Vector2i) -> bool:
	# Первый раунд: только центральные поля
	if round_number == 1:
		var start_positions = get_start_positions_for_player(active_player_id)
		var is_valid = pos in start_positions
		GameLogger.debug("Checking start position for round 1: %s = %s" % [Game.pos_to_chess(pos), str(is_valid)])
		return is_valid
	
	# Для последующих раундов: определяем, есть ли на доске вражеские G
	var has_enemy_gear = false
	for row in board.cells:
		for cell in row:
			if cell.occupied_gear and not cell.occupied_gear.is_owned_by(active_player_id):
				has_enemy_gear = true
				break
		if has_enemy_gear:
			break
	
	# Если вражеских G нет, можно начинать с любой пустой клетки своего цвета
	if not has_enemy_gear:
		var is_white = Game.is_cell_white(pos)
		var color_ok = (active_player_id == 0 and is_white) or (active_player_id == 1 and not is_white)
		var empty = board.cells[pos.x][pos.y].is_empty()
		GameLogger.debug("Checking start position (no enemy gears): %s color ok=%s empty=%s" % [Game.pos_to_chess(pos), str(color_ok), str(empty)])
		return color_ok and empty
	
	# Если вражеские G есть, можно начинать только с клеток, примыкающих к ним
	for row in board.cells:
		for cell in row:
			if cell.occupied_gear and not cell.occupied_gear.is_owned_by(active_player_id):
				var enemy_pos = cell.board_pos
				var neighbors = [
					Vector2i(enemy_pos.x + 1, enemy_pos.y),
					Vector2i(enemy_pos.x - 1, enemy_pos.y),
					Vector2i(enemy_pos.x, enemy_pos.y + 1),
					Vector2i(enemy_pos.x, enemy_pos.y - 1)
				]
				if pos in neighbors:
					var is_white = Game.is_cell_white(pos)
					var color_ok = (active_player_id == 0 and is_white) or (active_player_id == 1 and not is_white)
					var empty = board.cells[pos.x][pos.y].is_empty()
					GameLogger.debug("Checking start position (adjacent to enemy): %s color ok=%s empty=%s enemy at %s" % [Game.pos_to_chess(pos), str(color_ok), str(empty), Game.pos_to_chess(enemy_pos)])
					return color_ok and empty
	GameLogger.debug("Start position not valid: %s" % Game.pos_to_chess(pos))
	return false

# Проверка соседства клеток (ортогонально)
func is_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	return abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y) == 1

# Установка шестерёнки из руки на клетку
func place_gear_from_hand(cell: Cell, player: Player) -> bool:
	if not selected_gear:
		GameLogger.warning("No gear selected")
		return false
	# Проверяем, что выбранная шестерёнка принадлежит игроку и находится у него в руке
	if not selected_gear.is_owned_by(player.owner_id) or not (selected_gear in player.hand):
		GameLogger.warning("Wrong gear selected")
		selected_gear = null
		ui.clear_selection()
		return false
	
	# Убираем шестерёнку из руки игрока
	player.remove_from_hand(selected_gear)
	# Помещаем её на клетку
	cell.set_occupied(selected_gear)
	selected_gear.set_cell_size(Game.CELL_SIZE, Game.CELL_INDENT)  # Масштабируем под размер клетки
	
	# Подключаем сигналы шестерёнки для обработки событий
	selected_gear.rotated.connect(_on_gear_rotated)
	selected_gear.triggered.connect(_on_gear_triggered)
	selected_gear.destroyed.connect(_on_gear_destroyed)
	selected_gear.clicked.connect(_on_gear_clicked)
	selected_gear.mouse_entered.connect(_on_gear_mouse_entered)
	selected_gear.mouse_exited.connect(_on_gear_mouse_exited)
	
	selected_gear = null
	ui.clear_selection()
	GameLogger.debug("Gear placed on board")
	return true

# Добавление ребра между двумя клетками в графе цепочки
func add_edge(from_pos: Vector2i, to_pos: Vector2i):
	current_edge_index += 1
	var edge_id = current_edge_index
	
	# Если клетки ещё нет в графе, создаём для неё пустой словарь
	if not chain_graph.has(from_pos):
		chain_graph[from_pos] = {}
	if not chain_graph.has(to_pos):
		chain_graph[to_pos] = {}
	
	# Записываем ребро в обе стороны (неориентированный граф)
	chain_graph[from_pos][to_pos] = edge_id
	chain_graph[to_pos][from_pos] = edge_id
	
	GameLogger.debug("Added edge %d between %s and %s" % [edge_id, Game.pos_to_chess(from_pos), Game.pos_to_chess(to_pos)])

# Возвращает список стартовых позиций для игрока в первом раунде
func get_start_positions_for_player(player: int) -> Array[Vector2i]:
	if player == 0:
		return [Vector2i(3,4), Vector2i(4,3)]   # d5, e4 (индексы от 0)
	else:
		return [Vector2i(3,3), Vector2i(4,4)]   # d4, e5

# Завершение фазы построения цепочки, переход к upturn
func end_chain_building():
	current_phase = Game.GamePhase.UPTURN
	GameLogger.info("Chain building phase ended. Starting upturn phase.")
	update_ui()

# Завершение фазы upturn, переход к разрешению цепочки
func end_upturn():
	current_phase = Game.GamePhase.CHAIN_RESOLUTION
	GameLogger.info("Upturn phase ended. Starting chain resolution.")
	update_ui()
	start_chain_resolution()

# ------------------------------------------------------------------
# Логика фазы разрешения цепочки
# ------------------------------------------------------------------
func start_chain_resolution():
	if chain_graph.is_empty():
		end_chain_resolution()
		return
	# Начинаем с последней клетки цепочки
	current_resolve_pos = last_cell_pos
	came_from_edge = -1
	waiting_for_player = false
	resolve_current_gear()

func resolve_current_gear():
	if current_resolve_pos == Vector2i(-1, -1):
		end_chain_resolution()
		return
	
	var cell = board.cells[current_resolve_pos.x][current_resolve_pos.y]
	var gear = cell.occupied_gear
	if not gear:
		# Если клетка пуста (например, шестерёнка была уничтожена), переходим к следующей
		GameLogger.debug("Cell %s is empty, moving on" % Game.pos_to_chess(current_resolve_pos))
		current_resolve_pos = get_next_cell()
		resolve_current_gear()
		return
	
	GameLogger.info("Resolving gear at %s" % Game.pos_to_chess(current_resolve_pos))
	# Обязательный автоматический тик (do_tick)
	if gear.can_rotate():
		gear.do_tick(1)
		update_ui()
	
	# После автоматического тика ждём возможных действий игрока (дополнительные тики за T)
	waiting_for_player = true
	GameLogger.debug("Waiting for player action for gear at %s" % Game.pos_to_chess(current_resolve_pos))

# Определение следующей клетки для разрешения (движемся по рёбрам с наибольшим индексом)
func get_next_cell() -> Vector2i:
	var edges = chain_graph.get(current_resolve_pos, {}).duplicate()
	# Убираем ребро, по которому мы пришли (чтобы не возвращаться назад)
	if came_from_edge != -1:
		for neighbor in edges.keys():
			if edges[neighbor] == came_from_edge:
				edges.erase(neighbor)
				break
	if edges.is_empty():
		GameLogger.debug("No available edges from %s – end of chain" % Game.pos_to_chess(current_resolve_pos))
		return Vector2i(-1, -1)
	
	# Выбираем ребро с максимальным индексом (так мы идём от последней к первой)
	var max_edge = -1
	var next_pos = Vector2i(-1, -1)
	for neighbor in edges:
		var eid = edges[neighbor]
		if eid > max_edge:
			max_edge = eid
			next_pos = neighbor
	
	came_from_edge = max_edge
	GameLogger.debug("From %s going to %s via edge %d" % [Game.pos_to_chess(current_resolve_pos), Game.pos_to_chess(next_pos), max_edge])
	return next_pos

# Продолжить разрешение после того, как игрок закончил действия (или пропустил)
func proceed_to_next_cell():
	waiting_for_player = false
	var next_pos = get_next_cell()
	if next_pos == Vector2i(-1, -1):
		end_chain_resolution()
	else:
		current_resolve_pos = next_pos
		resolve_current_gear()

# Завершение фазы разрешения, переход к renewal
func end_chain_resolution():
	current_phase = Game.GamePhase.RENEWAL
	GameLogger.info("Chain resolution phase ended. Starting renewal.")
	# Наносим урон: каждый игрок получает урон, равный T в пуле противника
	for i in [0,1]:
		var damage = t_pool[i]
		players[1-i].damage += damage
		t_pool[i] = 0
	# Проверяем, не достиг ли кто-то лимита урона
	for p in players:
		if p.damage >= Game.MAX_DAMAGE:
			end_game(p.player_id)
			return
	# Игроки добирают по одной карте
	for p in players:
		p.draw_card()
	GameLogger.debug("end_chain_resolution: before changing active_player_id = %d, start_player_id = %d" % [active_player_id, start_player_id])
	# Активным становится другой игрок (не тот, кто начинал раунд)
	active_player_id = 1 - start_player_id
	GameLogger.debug("end_chain_resolution: after changing active_player_id = %d" % active_player_id)
	round_number += 1
	GameLogger.debug("end_chain_resolution: round_number now = %d" % round_number)
	start_round()   # Начинаем новый раунд

# Завершение игры (победа одного из игроков)
func end_game(winner_id: int):
	GameLogger.info("Player %d wins!" % (winner_id + 1))
	get_tree().paused = true   # Останавливаем игру (можно потом показать экран победы)

# ------------------------------------------------------------------
# Обработка событий от шестерёнок (Gear)
# ------------------------------------------------------------------
func _on_gear_rotated(gear: Node2D, old_ticks: int, new_ticks: int):
	update_ui()
	GameLogger.debug("Gear rotated: %d -> %d" % [old_ticks, new_ticks])

func _on_gear_triggered(gear: Node2D):
	gear.apply_effect()
	update_ui()
	GameLogger.info("Gear triggered!")

func _on_gear_destroyed(gear: Node2D):
	var cell = gear.get_parent() as Cell
	if cell:
		var pos = cell.board_pos
		cell.occupied_gear = null
		GameLogger.info("Gear destroyed at %s" % Game.pos_to_chess(pos))
		# Удаляем клетку из графа цепочки
		if chain_graph.has(pos):
			chain_graph.erase(pos)
		# Удаляем все рёбра, ведущие к этой клетке
		for other_pos in chain_graph.keys():
			if chain_graph[other_pos].has(pos):
				chain_graph[other_pos].erase(pos)
		# Если уничтожена последняя клетка цепочки, откатываем last_cell_pos на предыдущую (если возможно)
		if pos == last_cell_pos:
			if last_from_pos != Vector2i(-1, -1) and board.cells[last_from_pos.x][last_from_pos.y].occupied_gear != null:
				last_cell_pos = last_from_pos
			else:
				last_cell_pos = Vector2i(-1, -1)
			last_from_pos = Vector2i(-1, -1)
		# Если мы в фазе разрешения и уничтожена текущая разрешаемая клетка, переходим к следующей
		if current_phase == Game.GamePhase.CHAIN_RESOLUTION and pos == current_resolve_pos:
			waiting_for_player = false
			proceed_to_next_cell()
	update_ui()

func _on_gear_clicked(gear: Node2D):
	# В зависимости от фазы вызываем соответствующий обработчик
	match current_phase:
		Game.GamePhase.CHAIN_BUILDING:
			handle_chain_building_gear_click(gear)
		Game.GamePhase.UPTURN:
			handle_upturn_gear_click(gear)
		Game.GamePhase.CHAIN_RESOLUTION:
			handle_resolution_gear_click(gear)
		_:
			pass

# Клик по шестерёнке в фазе построения цепочки (снятие T)
func handle_chain_building_gear_click(gear: Node2D):
	if not has_placed_this_turn:
		GameLogger.warning("You need to place a gear in the chain first")
		return
	
	if not gear.is_owned_by(active_player_id):
		GameLogger.warning("This is not your gear")
		return
	
	var cell = gear.get_parent() as Cell
	if not cell or not chain_graph.has(cell.board_pos):
		GameLogger.warning("This gear is not in the current chain")
		return
	
	if not gear.can_rotate():
		GameLogger.warning("Gear has already triggered and cannot rotate")
		return
	
	# Снимаем 1 T с шестерёнки (поворот против часовой стрелки)
	# Если шестерёнка уничтожается (достигнут плохой конец), это обработается автоматически
	var success = gear.do_tock(1)
	if success:
		t_pool[active_player_id] += 1
		update_ui()
		GameLogger.info("Taken 1 T from gear. Total T%d: %d" % [active_player_id, t_pool[active_player_id]])
	else:
		GameLogger.warning("Could not take T from gear")

# Клик по шестерёнке в фазе upturn (просмотр чужой G за T)
func handle_upturn_gear_click(gear: Node2D):
	if not gear.is_owned_by(active_player_id) and not gear.is_face_up:
		if t_pool[active_player_id] > 0:
			t_pool[active_player_id] -= 1
			gear.show_obverse_temporarily()   # Показываем аверс на 2 секунды
			update_ui()
			GameLogger.info("Spent T to peek. Remaining T%d: %d" % [active_player_id, t_pool[active_player_id]])
		else:
			GameLogger.warning("Not enough T to peek")
	else:
		GameLogger.warning("Cannot peek at your own or already flipped gear")

# Клик по шестерёнке в фазе разрешения (дополнительные тики за T)
func handle_resolution_gear_click(gear: Node2D):
	if not waiting_for_player:
		return
	var cell = board.cells[current_resolve_pos.x][current_resolve_pos.y]
	if gear != cell.occupied_gear:
		GameLogger.warning("Another gear is being resolved now")
		return
	
	if not gear.is_owned_by(active_player_id):
		GameLogger.warning("Not your gear")
		return
	
	if not gear.can_rotate():
		GameLogger.warning("Gear cannot rotate")
		return
	
	if t_pool[active_player_id] <= 0:
		GameLogger.warning("Not enough T")
		return
	
	# Тратим 1 T на дополнительный тик (поворот по часовой стрелке)
	var success = gear.do_tick(1)
	if success:
		t_pool[active_player_id] -= 1
		update_ui()
		GameLogger.info("Spent 1 T on extra tick. Remaining T%d: %d" % [active_player_id, t_pool[active_player_id]])
	else:
		GameLogger.warning("Could not rotate gear")

# Отображение тултипа при наведении на свою шестерёнку
func _on_gear_mouse_entered(gear: Node2D):
	if gear.is_owned_by(active_player_id):
		ui.show_gear_tooltip(gear, get_viewport().get_mouse_position())

func _on_gear_mouse_exited(gear: Node2D):
	ui.hide_gear_tooltip()

# ------------------------------------------------------------------
# Обработка событий от UI
# ------------------------------------------------------------------
# Выбор шестерёнки в руке
func _on_hand_gear_selected(gear: Node2D):
	if selected_gear:
		ui.unhighlight_gear(selected_gear)
	selected_gear = gear
	ui.highlight_gear(gear)
	GameLogger.debug("Gear selected from hand")

# Нажатие на главную кнопку действия (меняется в зависимости от фазы)
func _on_action_button_pressed():
	match current_phase:
		Game.GamePhase.CHAIN_BUILDING:
			if has_placed_this_turn:
				# Завершение хода: передаём ход противнику
				active_player_id = 1 - active_player_id
				has_placed_this_turn = false
				# Проверяем, есть ли у нового игрока доступные ходы
				if get_available_cells().is_empty():
					GameLogger.info("Player %d has no available moves. Chain ends." % (active_player_id + 1))
					end_chain_building()
				else:
					GameLogger.info("Turn passed to player %d" % (active_player_id + 1))
				update_ui()
			else:
				# Пас
				if can_pass():
					GameLogger.info("Player %d passes. Chain ends." % (active_player_id + 1))
					end_chain_building()
				else:
					GameLogger.warning("Pass not available: you haven't made a move this round or the round just started.")
		Game.GamePhase.UPTURN:
			GameLogger.info("Ending upturn phase")
			end_upturn()
		Game.GamePhase.CHAIN_RESOLUTION:
			if waiting_for_player:
				GameLogger.debug("Skipping current gear")
				proceed_to_next_cell()
		Game.GamePhase.RENEWAL:
			# В renewal кнопка обычно неактивна или ничего не делает
			pass

# Проверка, можно ли пасовать
func can_pass() -> bool:
	# Пас разрешён, если игрок ещё не делал ход в этом раунде (has_placed_this_turn == false)
	# и уже прошло как минимум 2 хода (оба игрока походили) – то есть moves_in_round >= 2
	return not has_placed_this_turn and moves_in_round >= 2

# ------------------------------------------------------------------
# Обновление интерфейса и подсветка клеток
# ------------------------------------------------------------------
func update_ui():
	ui.update_player(active_player_id)
	ui.update_phase(current_phase)
	ui.update_t_pool(t_pool[0], t_pool[1])
	ui.update_action_button(current_phase, has_placed_this_turn, active_player_id, can_pass())
	ui.update_hands(players[0].hand, players[1].hand, active_player_id)
	ui.update_round(round_number)
	ui.update_chain_length(chain_graph.size())
	ui.update_prompt(get_prompt_text())
	ui.update_damage(players[0].damage, players[1].damage)
	highlight_available_cells()
	highlight_chain_cells()
	
	# Логируем подсказку только если она изменилась
	var current_prompt = get_prompt_text()
	if current_prompt != last_prompt:
		GameLogger.prompt(current_prompt)
		last_prompt = current_prompt

# Сброс цвета всех клеток на стандартный (белые/чёрные)
func reset_cell_colors():
	for row in board.cells:
		for cell in row:
			if cell.is_white():
				cell.sprite.modulate = Color(1, 1, 1, 0.8)
			else:
				cell.sprite.modulate = Color(0.2, 0.2, 0.2, 0.8)

# Подсветка доступных для хода клеток (жёлтым)
func highlight_available_cells():
	reset_cell_colors()
	if current_phase != Game.GamePhase.CHAIN_BUILDING:
		return
	var available = get_available_cells()
	GameLogger.debug("Available cells: %s" % str(available.map(func(c): return Game.pos_to_chess(c.board_pos))))
	for cell in available:
		cell.sprite.modulate = Color.YELLOW

# Возвращает список клеток, доступных для хода в текущей фазе построения
func get_available_cells() -> Array[Cell]:
	var result: Array[Cell] = []
	
	# --- Случай, когда цепочка ещё не начата ---
	if last_cell_pos == Vector2i(-1, -1):
		if round_number == 1:
			# Первый раунд: только центральные поля
			var start_positions = get_start_positions_for_player(active_player_id)
			for pos in start_positions:
				var cell = board.cells[pos.x][pos.y] as Cell
				if cell.is_empty():
					result.append(cell)
					GameLogger.debug("Added start cell: %s" % Game.pos_to_chess(pos))
		else:
			# Последующие раунды
			var has_enemy_gear = false
			for row in board.cells:
				for cell in row:
					if cell.occupied_gear and not cell.occupied_gear.is_owned_by(active_player_id):
						has_enemy_gear = true
						break
				if has_enemy_gear:
					break
			
			if has_enemy_gear:
				# Только клетки, примыкающие к вражеским G
				var candidates: Array[Cell] = []
				for row in board.cells:
					for cell in row:
						if cell.occupied_gear and not cell.occupied_gear.is_owned_by(active_player_id):
							var enemy_pos = cell.board_pos
							var neighbors = [
								Vector2i(enemy_pos.x + 1, enemy_pos.y),
								Vector2i(enemy_pos.x - 1, enemy_pos.y),
								Vector2i(enemy_pos.x, enemy_pos.y + 1),
								Vector2i(enemy_pos.x, enemy_pos.y - 1)
							]
							for n in neighbors:
								if n.x >= 0 and n.x < Game.BOARD_SIZE and n.y >= 0 and n.y < Game.BOARD_SIZE:
									var neighbor_cell = board.cells[n.x][n.y] as Cell
									if neighbor_cell.is_empty():
										if (active_player_id == 0 and neighbor_cell.is_white()) or (active_player_id == 1 and neighbor_cell.is_black()):
											if not neighbor_cell in candidates:
												candidates.append(neighbor_cell)
												GameLogger.debug("Added cell adjacent to enemy: %s (enemy at %s)" % [Game.pos_to_chess(n), Game.pos_to_chess(enemy_pos)])
				result = candidates
			else:
				# Нет вражеских G – все пустые клетки своего цвета
				for row in board.cells:
					for cell in row:
						if cell.is_empty():
							if (active_player_id == 0 and cell.is_white()) or (active_player_id == 1 and cell.is_black()):
								result.append(cell)
								GameLogger.debug("Added empty cell of own color: %s" % Game.pos_to_chess(cell.board_pos))
		return result
	
	# --- Цепочка не пуста – проверяем соседей последней клетки ---
	var neighbors = [
		Vector2i(last_cell_pos.x + 1, last_cell_pos.y),
		Vector2i(last_cell_pos.x - 1, last_cell_pos.y),
		Vector2i(last_cell_pos.x, last_cell_pos.y + 1),
		Vector2i(last_cell_pos.x, last_cell_pos.y - 1)
	]
	
	GameLogger.debug("Checking neighbors from last cell %s" % Game.pos_to_chess(last_cell_pos))
	for n in neighbors:
		if n.x < 0 or n.x >= Game.BOARD_SIZE or n.y < 0 or n.y >= Game.BOARD_SIZE:
			GameLogger.debug("  Neighbor out of bounds – off board")
			continue
		
		var cell = board.cells[n.x][n.y] as Cell
		var color_ok = (active_player_id == 0 and cell.is_white()) or (active_player_id == 1 and cell.is_black())
		GameLogger.debug("  Neighbor %s is_white=%s color ok=%s empty=%s" % [Game.pos_to_chess(n), str(cell.is_white()), str(color_ok), str(cell.is_empty())])
		
		if not color_ok:
			GameLogger.debug("    → does not match color")
			continue
		
		if cell.is_empty():
			result.append(cell)
			GameLogger.debug("    → added (empty)")
			continue
		
		# Клетка занята – проверяем, можно ли использовать эту G (своя и нет прямого ребра)
		if cell.occupied_gear.is_owned_by(active_player_id):
			var has_direct_edge = chain_graph[last_cell_pos].has(n)
			GameLogger.debug("    occupied by own gear, direct edge already exists? %s" % str(has_direct_edge))
			if not has_direct_edge:
				result.append(cell)
				GameLogger.debug("    → added (own gear without direct edge)")
			else:
				GameLogger.debug("    → not added (direct edge exists)")
		else:
			GameLogger.debug("    occupied by enemy gear – not suitable")
	
	return result

# Подсветка клеток, входящих в текущую цепочку
func highlight_chain_cells():
	# Сначала сбрасываем подсветку у всех клеток
	for row in board.cells:
		for cell in row:
			cell.set_highlighted(false)
	# Затем подсвечиваем клетки текущей цепочки
	for pos in chain_graph.keys():
		var cell = board.cells[pos.x][pos.y]
		cell.set_highlighted(true)
		GameLogger.debug("Chain cell highlighted: %s" % Game.pos_to_chess(pos))

# ------------------------------------------------------------------
# Текстовая подсказка для игрока (отображается в UI)
# ------------------------------------------------------------------
func get_prompt_text() -> String:
	match current_phase:
		Game.GamePhase.CHAIN_BUILDING:
			if last_cell_pos == Vector2i(-1, -1):
				return "Select a starting cell and a gear from hand"
			elif not has_placed_this_turn:
				if moves_in_round < 2:
					return "You must make a move (continue the chain)"
				else:
					return "You can make a move or press Pass"
			else:
				return "You can take T from gears in the chain (click on them) or press End Turn"
		Game.GamePhase.UPTURN:
			return "Click on an opponent's gear to peek for 1 T or press End Peek"
		Game.GamePhase.CHAIN_RESOLUTION:
			if waiting_for_player:
				return "Click on current gear for an extra tick for 1 T or press Skip"
			else:
				return "Resolving chain..."
		Game.GamePhase.RENEWAL:
			return "Renewal..."
		_:
			return ""
