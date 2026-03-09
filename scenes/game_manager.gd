# game_manager.gd
class_name GameManager
extends Node

static var ref: GameManager = null

@onready var board: Node2D = $Board
@onready var ui: UI = $UI

const PLAYER_SCENE = preload("res://scenes/Player.tscn")
const GEAR_SCENE = preload("res://scenes/Gear.tscn")

# -------------------- Состояние игры --------------------
var current_phase: Game.GamePhase = Game.GamePhase.CHAIN_BUILDING
var active_player_id: int = 0
var round_number: int = 1
var start_player_id: int = 0
var players: Array[Player] = []
var t_pool: Array[int] = [0, 0]
var passed: bool = false

# -------------------- Построение цепочки --------------------
var chain_graph: Dictionary = {}
var last_cell_pos: Vector2i = Vector2i(-1, -1)
var last_from_pos: Vector2i = Vector2i(-1, -1)
var current_edge_index: int = 0
var has_placed_this_turn: bool = false
var moves_in_round: int = 0
var selected_gear: Gear = null

# -------------------- Разрешение цепочки --------------------
var current_resolve_pos: Vector2i = Vector2i(-1, -1)
var came_from_edge: int = -1
var waiting_for_player: bool = false

# -------------------- Способности --------------------
var static_effects: Array[Dictionary] = []  # {gear: Gear, ability: Ability}
var prevent_trigger: Dictionary = {}        # Gear -> true
var used_abilities_on_gear: Dictionary = {}  # ключ: Gear, значение: Dictionary {ability_id: true}

# -------------------- Подсветка активной клетки --------------------
var _last_active_pos: Vector2i = Vector2i(-1, -1)

# -------------------- Инициализация --------------------
func _ready():
	ref = self
	initialize_game()
	ui.action_pressed.connect(_on_action_button_pressed)
	ui.hand_gear_selected.connect(_on_hand_gear_selected)
	GameLogger.info("GameManager ready")

func initialize_game():
	var deck_data = load_decks_from_json("res://data/gears.json")
	var deck1: Array[GearData] = deck_data.duplicate()
	var deck2: Array[GearData] = deck_data.duplicate()
	deck1.shuffle()
	deck2.shuffle()
	
	var player1 = PLAYER_SCENE.instantiate()
	var player2 = PLAYER_SCENE.instantiate()
	player1.player_id = 0
	player1.owner_id = 0
	player1.deck = deck1
	player1.draw_starting_hand(Game.START_HAND_SIZE)
	player2.player_id = 1
	player2.owner_id = 1
	player2.deck = deck2
	player2.draw_starting_hand(Game.START_HAND_SIZE)
	add_child(player1)
	add_child(player2)
	players = [player1, player2]
	
	board.generate_board()
	for row in board.cells:
		for cell in row:
			cell.clicked.connect(_on_cell_clicked)
	
	start_round()
	GameLogger.info("Game initialized")

func clear_used_abilities():
	used_abilities_on_gear.clear()

func is_ability_used_on_gear(gear: Gear, ability_id: int) -> bool:
	var dict = used_abilities_on_gear.get(gear)
	return dict != null and dict.has(ability_id)

func mark_ability_used_on_gear(gear: Gear, ability_id: int):
	if not used_abilities_on_gear.has(gear):
		used_abilities_on_gear[gear] = {}
	used_abilities_on_gear[gear][ability_id] = true

# -------------------- Загрузка из JSON --------------------
func load_decks_from_json(path: String) -> Array[GearData]:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		GameLogger.error("Cannot open JSON file: " + path)
		return []
	var text = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		GameLogger.error("JSON parse error: " + json.get_error_message())
		return []
	var data = json.data
	var result: Array[GearData] = []
	for entry in data:
		var gd = GearData.new()
		gd.gear_name = entry.get("name", "Unknown")
		var reverse_path = entry.get("texture_reverse", "")
		var obverse_path = entry.get("texture_obverse", "")
		if reverse_path:
			gd.texture_reverse = load(reverse_path)
		if obverse_path:
			gd.texture_obverse = load(obverse_path)
		gd.max_ticks = entry.get("max_ticks", 3)
		gd.max_tocks = entry.get("max_tocks", 2)
		var ability_ids = entry.get("abilities", [])
		for aid in ability_ids:
			var ability = create_ability_by_id(aid)
			if ability:
				gd.abilities.append(ability)
		result.append(gd)
	return result

func create_ability_by_id(id: int) -> Ability:
	var script_path = ""
	match id:
		GameEnums.AbilityID.SPRING:
			script_path = "res://resources/abilities/spring_ability.gd"
		GameEnums.AbilityID.TIME_SWARM:
			script_path = "res://resources/abilities/time_swarm_ability.gd"
		GameEnums.AbilityID.REPEAT:
			script_path = "res://resources/abilities/repeat_ability.gd"
		GameEnums.AbilityID.MANA_LEAK:
			script_path = "res://resources/abilities/mana_leak_ability.gd"
		_:
			return null
	
	var script = load(script_path)
	if script:
		return script.new() as Ability
	else:
		GameLogger.error("Could not load ability script: " + script_path)
		return null

# -------------------- Управление статическими эффектами --------------------
func register_static_effect(gear: Gear, ability: Ability):
	static_effects.append({"gear": gear, "ability": ability})
	GameLogger.debug("Activated static effect: " + ability.ability_name + " for gear " + gear.gear_name)

func unregister_gear_effects(gear: Gear):
	for i in range(static_effects.size() - 1, -1, -1):
		if static_effects[i].gear == gear:
			static_effects.remove_at(i)
			GameLogger.debug("Unregistered static effect for gear")

func should_skip_auto_tick(gear: Gear) -> bool:
	for eff in static_effects:
		if eff.ability.ability_id == GameEnums.AbilityID.TIME_SWARM and eff.gear.owner_id != gear.owner_id:
			return true
	return false

func is_trigger_prevented(gear: Gear) -> bool:
	return prevent_trigger.has(gear)

func apply_mana_leak(target: Gear):
	prevent_trigger[target] = true
	GameLogger.info("Mana Leak applied to gear at " + Game.pos_to_chess(target.board_position))

# -------------------- События (заглушка) --------------------
func emit_event(trigger: int, context: Dictionary):
	GameLogger.debug("Event emitted: " + str(trigger) + " context: " + str(context))

# -------------------- Управление раундами --------------------
func start_round():
	_set_active_cell(Vector2i(-1, -1))   # сброс красной рамки
	clear_used_abilities()
	start_player_id = active_player_id
	GameLogger.info("=== Round %d. Active player: %d ===" % [round_number, active_player_id + 1])
	chain_graph.clear()
	last_cell_pos = Vector2i(-1, -1)
	last_from_pos = Vector2i(-1, -1)
	current_edge_index = 0
	passed = false
	current_phase = Game.GamePhase.CHAIN_BUILDING
	has_placed_this_turn = false
	moves_in_round = 0
	selected_gear = null
	ui.clear_selection()
	update_ui()
	emit_event(GameEnums.TriggerCondition.ON_PHASE_START, {"phase": current_phase, "round": round_number})

func end_chain_building():
	current_phase = Game.GamePhase.UPTURN
	GameLogger.info("Chain building phase ended. Starting upturn phase.")
	emit_event(GameEnums.TriggerCondition.ON_PHASE_END, {"phase": Game.GamePhase.CHAIN_BUILDING})
	update_ui()

func end_upturn():
	current_phase = Game.GamePhase.CHAIN_RESOLUTION
	GameLogger.info("Upturn phase ended. Starting chain resolution.")
	emit_event(GameEnums.TriggerCondition.ON_PHASE_END, {"phase": Game.GamePhase.UPTURN})
	update_ui()
	start_chain_resolution()

func end_chain_resolution():
	_set_active_cell(Vector2i(-1, -1))   # сброс красной рамки
	current_phase = Game.GamePhase.RENEWAL
	GameLogger.info("Chain resolution phase ended. Starting renewal.")
	for i in [0,1]:
		var damage = t_pool[i]
		players[1-i].damage += damage
		t_pool[i] = 0
	for p in players:
		if p.damage >= Game.MAX_DAMAGE:
			end_game(p.player_id)
			return
	for p in players:
		p.draw_card()
	active_player_id = 1 - start_player_id
	round_number += 1
	emit_event(GameEnums.TriggerCondition.ON_PHASE_END, {"phase": Game.GamePhase.CHAIN_RESOLUTION})
	start_round()

func end_game(winner_id: int):
	GameLogger.info("Player %d wins!" % (winner_id + 1))
	get_tree().paused = true

# -------------------- Обработка кликов по клеткам --------------------
func _on_cell_clicked(cell: Cell):
	var board_pos = cell.board_pos
	GameLogger.debug("Click on cell %s (%s) phase: %s" % [str(board_pos), Game.pos_to_chess(board_pos), str(current_phase)])
	match current_phase:
		Game.GamePhase.CHAIN_BUILDING:
			handle_chain_building_click(cell)
		_:
			pass

func handle_chain_building_click(cell: Cell):
	var board_pos = cell.board_pos
	if has_placed_this_turn:
		GameLogger.warning("You have already made a move. Press 'End Turn' button to pass the turn.")
		return
	var is_white = cell.is_white()
	var current_player = players[active_player_id]
	if current_player.owner_id == 0 and not is_white:
		GameLogger.warning("Player 1 can only place on white cells")
		return
	if current_player.owner_id == 1 and is_white:
		GameLogger.warning("Player 2 can only place on black cells")
		return
	
	if last_cell_pos == Vector2i(-1, -1):
		if not is_valid_start_position(board_pos):
			GameLogger.warning("Cannot start chain from this cell")
			return
		if not cell.is_empty():
			GameLogger.warning("Starting cell must be empty")
			return
		if not place_gear_from_hand(cell, current_player):
			return
		t_pool[active_player_id] += 1
		chain_graph[board_pos] = {}
		last_cell_pos = board_pos
		GameLogger.info("First move of the round: gear placed on %s. T = %d" % [Game.pos_to_chess(board_pos), t_pool[active_player_id]])
		on_successful_placement()
		return
	
	if not is_adjacent(last_cell_pos, board_pos):
		GameLogger.warning("Cell is not adjacent to the last one")
		return
	
	if cell.is_empty():
		if not place_gear_from_hand(cell, current_player):
			return
		t_pool[active_player_id] += 1
		add_edge(last_cell_pos, board_pos)
		last_from_pos = last_cell_pos
		last_cell_pos = board_pos
		GameLogger.info("New gear placed on %s. T = %d" % [Game.pos_to_chess(board_pos), t_pool[active_player_id]])
		on_successful_placement()
		return
	
	var gear = cell.occupied_gear
	if not gear.is_owned_by(active_player_id):
		GameLogger.warning("This is not your gear")
		return
	
	if chain_graph[last_cell_pos].has(board_pos):
		GameLogger.warning("Cannot create double connection (2-cycle)")
		return
	
	if chain_graph.has(board_pos):
		if board_pos == last_cell_pos:
			GameLogger.warning("Cannot use the same cell as the last one")
			return
		add_edge(last_cell_pos, board_pos)
		last_from_pos = last_cell_pos
		last_cell_pos = board_pos
		GameLogger.info("Cycle formed at %s. Chain building phase ends." % Game.pos_to_chess(board_pos))
		on_successful_placement()
		end_chain_building()
		return
	else:
		add_edge(last_cell_pos, board_pos)
		last_from_pos = last_cell_pos
		last_cell_pos = board_pos
		GameLogger.info("Existing gear on board used at %s" % Game.pos_to_chess(board_pos))
		on_successful_placement()
		return

func on_successful_placement():
	has_placed_this_turn = true
	moves_in_round += 1
	update_ui()

func is_valid_start_position(pos: Vector2i) -> bool:
	if round_number == 1:
		var start_positions = get_start_positions_for_player(active_player_id)
		return pos in start_positions
	var has_enemy_gear = false
	for row in board.cells:
		for cell in row:
			if cell.occupied_gear and not cell.occupied_gear.is_owned_by(active_player_id):
				has_enemy_gear = true
				break
		if has_enemy_gear:
			break
	if not has_enemy_gear:
		var is_white = Game.is_cell_white(pos)
		var color_ok = (active_player_id == 0 and is_white) or (active_player_id == 1 and not is_white)
		var empty = board.cells[pos.x][pos.y].is_empty()
		return color_ok and empty
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
					return color_ok and empty
	return false

func is_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	return abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y) == 1

func place_gear_from_hand(cell: Cell, player: Player) -> bool:
	if not selected_gear:
		GameLogger.warning("No gear selected")
		return false
	if not selected_gear.is_owned_by(player.owner_id) or not (selected_gear in player.hand):
		GameLogger.warning("Wrong gear selected")
		selected_gear = null
		ui.clear_selection()
		return false
	player.remove_from_hand(selected_gear)
	cell.set_occupied(selected_gear)
	selected_gear.set_cell_size(Game.CELL_SIZE, Game.CELL_INDENT)
	selected_gear.board_position = cell.board_pos
	
	selected_gear.rotated.connect(_on_gear_rotated)
	selected_gear.triggered.connect(_on_gear_triggered)
	selected_gear.destroyed.connect(_on_gear_destroyed)
	selected_gear.clicked.connect(_on_gear_clicked)
	selected_gear.mouse_entered.connect(_on_gear_mouse_entered)
	selected_gear.mouse_exited.connect(_on_gear_mouse_exited)
	
	emit_event(GameEnums.TriggerCondition.ON_PLACED, {"gear": selected_gear, "cell": cell})
	
	var placed_gear = selected_gear
	selected_gear = null
	ui.clear_selection()
	GameLogger.debug("Gear '%s' placed on board at %s" % [placed_gear.gear_name, Game.pos_to_chess(cell.board_pos)])
	return true

func add_edge(from_pos: Vector2i, to_pos: Vector2i):
	current_edge_index += 1
	var edge_id = current_edge_index
	if not chain_graph.has(from_pos):
		chain_graph[from_pos] = {}
	if not chain_graph.has(to_pos):
		chain_graph[to_pos] = {}
	chain_graph[from_pos][to_pos] = edge_id
	chain_graph[to_pos][from_pos] = edge_id
	GameLogger.debug("Added edge %d between %s and %s" % [edge_id, Game.pos_to_chess(from_pos), Game.pos_to_chess(to_pos)])

func get_start_positions_for_player(player: int) -> Array[Vector2i]:
	if player == 0:
		return [Vector2i(3,4), Vector2i(4,3)]   # d5, e4
	else:
		return [Vector2i(3,3), Vector2i(4,4)]   # d4, e5

# -------------------- Обработка кликов по шестерням --------------------
func _on_gear_clicked(gear: Gear):
	GameLogger.debug("GameManager _on_gear_clicked: " + gear.gear_name)
	match current_phase:
		Game.GamePhase.CHAIN_BUILDING:
			handle_chain_building_gear_click(gear)
		Game.GamePhase.UPTURN:
			handle_upturn_gear_click(gear)
		Game.GamePhase.CHAIN_RESOLUTION:
			handle_resolution_gear_click(gear)
		_:
			pass

func handle_chain_building_gear_click(gear: Gear):
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
	var success = gear.do_tock(1)
	if success:
		t_pool[active_player_id] += 1
		update_ui()
		GameLogger.info("Taken 1 T from gear. Total T%d: %d" % [active_player_id, t_pool[active_player_id]])
	else:
		GameLogger.warning("Could not take T from gear")

func handle_upturn_gear_click(gear: Gear):
	if not gear.is_owned_by(active_player_id) and not gear.is_face_up:
		if t_pool[active_player_id] > 0:
			t_pool[active_player_id] -= 1
			gear.show_obverse_temporarily()
			update_ui()
			GameLogger.info("Spent T to peek. Remaining T%d: %d" % [active_player_id, t_pool[active_player_id]])
		else:
			GameLogger.warning("Not enough T to peek")
	else:
		GameLogger.warning("Cannot peek at your own or already flipped gear")

func handle_resolution_gear_click(gear: Gear):
	GameLogger.debug("handle_resolution_gear_click called for " + gear.gear_name)
	GameLogger.debug("waiting_for_player = " + str(waiting_for_player))
	GameLogger.debug("current_resolve_pos = " + str(current_resolve_pos))
	GameLogger.debug("gear.board_position = " + str(gear.board_position))
	if not waiting_for_player:
		GameLogger.debug("Not waiting for player, ignoring")
		return
	var cell = board.cells[current_resolve_pos.x][current_resolve_pos.y]
	if gear != cell.occupied_gear:
		GameLogger.debug("Gear mismatch: clicked gear not at current resolve pos")
		return
	if not gear.is_owned_by(active_player_id):
		GameLogger.debug("Not owned by active player")
		return
	if not gear.can_rotate():
		GameLogger.debug("Gear cannot rotate")
		return
	if t_pool[active_player_id] <= 0:
		GameLogger.debug("Not enough T")
		return
	
	var success = gear.do_tick(1)
	if success:
		t_pool[active_player_id] -= 1
		update_ui()
		GameLogger.info("Spent 1 T on extra tick")
	else:
		GameLogger.warning("Could not rotate gear")
	


func _on_gear_mouse_entered(gear: Gear):
	if gear.is_owned_by(active_player_id):
		ui.show_gear_tooltip(gear, get_viewport().get_mouse_position())

func _on_gear_mouse_exited(_gear: Gear):
	ui.hide_gear_tooltip()

func _on_gear_rotated(gear: Gear, old_ticks: int, new_ticks: int):
	update_ui()
	GameLogger.debug("Gear rotated: %d -> %d" % [old_ticks, new_ticks])
	if new_ticks > old_ticks:
		emit_event(GameEnums.TriggerCondition.ON_TICK, {"gear": gear, "old": old_ticks, "new": new_ticks})
	else:
		emit_event(GameEnums.TriggerCondition.ON_TOCK, {"gear": gear, "old": old_ticks, "new": new_ticks})

func _on_gear_triggered(gear: Gear):
	for ability in gear.abilities:
		if ability.ability_type == GameEnums.AbilityType.STATIC:
			var already = false
			for eff in static_effects:
				if eff.gear == gear and eff.ability == ability:
					already = true
					break
			if not already:
				register_static_effect(gear, ability)
	
	for ability in gear.abilities:
		if ability.ability_type == GameEnums.AbilityType.TRIGGERED and ability.trigger == GameEnums.TriggerCondition.ON_TRIGGER:
			ability.execute({"source_gear": gear})
	
	update_ui()

func _on_gear_destroyed(gear: Gear):
	var cell = gear.get_parent() as Cell
	if cell:
		cell.occupied_gear = null
		if chain_graph.has(cell.board_pos):
			chain_graph.erase(cell.board_pos)
		for other_pos in chain_graph.keys():
			if chain_graph[other_pos].has(cell.board_pos):
				chain_graph[other_pos].erase(cell.board_pos)
		if cell.board_pos == last_cell_pos:
			if last_from_pos != Vector2i(-1, -1) and board.cells[last_from_pos.x][last_from_pos.y].occupied_gear != null:
				last_cell_pos = last_from_pos
			else:
				last_cell_pos = Vector2i(-1, -1)
			last_from_pos = Vector2i(-1, -1)
	unregister_gear_effects(gear)
	emit_event(GameEnums.TriggerCondition.ON_DESTROYED, {"gear": gear})
	update_ui()
	_check_state_based_actions()

# -------------------- Проверки состояния (SBA) --------------------
func _check_state_based_actions():
	var actions_taken = false
	for row in board.cells:
		for cell in row:
			var gear = cell.occupied_gear
			if gear:
				if gear.current_ticks <= -gear.max_tocks:
					gear.destroy()
					actions_taken = true
					continue
				if gear.current_ticks >= gear.max_ticks and not gear.is_triggered:
					if not is_trigger_prevented(gear):
						gear.trigger()
					else:
						prevent_trigger.erase(gear)
						GameLogger.debug("Trigger prevented by Mana Leak")
					actions_taken = true
	if actions_taken:
		_check_state_based_actions()

# -------------------- Разрешение цепочки --------------------
func start_chain_resolution():
	GameLogger.debug("start_chain_resolution called, chain_graph size: " + str(chain_graph.size()))
	if chain_graph.is_empty():
		end_chain_resolution()
		return
	current_resolve_pos = last_cell_pos
	_set_active_cell(current_resolve_pos)   # подсветка красным
	came_from_edge = -1
	waiting_for_player = false
	var cell = board.cells[current_resolve_pos.x][current_resolve_pos.y]
	var gear = cell.occupied_gear
	if gear:
		active_player_id = gear.owner_id
	resolve_current_gear()

func resolve_current_gear():
	_set_active_cell(current_resolve_pos)   # обновление красной рамки
	GameLogger.debug("resolve_current_gear called, pos: " + Game.pos_to_chess(current_resolve_pos))
	if current_resolve_pos == Vector2i(-1, -1):
		end_chain_resolution()
		return
	var cell = board.cells[current_resolve_pos.x][current_resolve_pos.y]
	var gear = cell.occupied_gear
	if not gear:
		current_resolve_pos = get_next_cell()
		resolve_current_gear()
		return
	
	GameLogger.info("Resolving gear at %s" % Game.pos_to_chess(current_resolve_pos))
	var skip = should_skip_auto_tick(gear)
	GameLogger.debug("Auto tick skip: %s, can_rotate: %s, ticks: %d/%d" % [skip, gear.can_rotate(), gear.current_ticks, gear.max_ticks])
	if not skip:
		if gear.can_rotate():
			gear.do_tick(1)
			update_ui()
	else:
		GameLogger.debug("Auto tick prevented by Time Swarm")
	
	waiting_for_player = true
	GameLogger.debug("Waiting for player action for gear at %s" % Game.pos_to_chess(current_resolve_pos))

func get_next_cell() -> Vector2i:
	var edges = chain_graph.get(current_resolve_pos, {}).duplicate()
	if came_from_edge != -1:
		for neighbor in edges.keys():
			if edges[neighbor] == came_from_edge:
				edges.erase(neighbor)
				break
	if edges.is_empty():
		GameLogger.debug("No available edges from %s – end of chain" % Game.pos_to_chess(current_resolve_pos))
		return Vector2i(-1, -1)
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

func proceed_to_next_cell():
	waiting_for_player = false
	var next_pos = get_next_cell()
	if next_pos == Vector2i(-1, -1):
		end_chain_resolution()
	else:
		current_resolve_pos = next_pos
		var cell = board.cells[current_resolve_pos.x][current_resolve_pos.y]
		var gear = cell.occupied_gear
		if gear:
			active_player_id = gear.owner_id
		resolve_current_gear()

func restart_chain_resolution():
	GameLogger.info("Restarting chain resolution from last cell")
	waiting_for_player = false
	current_resolve_pos = last_cell_pos
	_set_active_cell(current_resolve_pos)   # подсветка красным
	came_from_edge = -1
	if current_resolve_pos == Vector2i(-1, -1):
		GameLogger.warning("No last cell to restart from")
		end_chain_resolution()
		return
	var cell = board.cells[current_resolve_pos.x][current_resolve_pos.y]
	var gear = cell.occupied_gear
	if gear:
		active_player_id = gear.owner_id
	resolve_current_gear()

# -------------------- Подсветка активной клетки --------------------
func _set_active_cell(pos: Vector2i):
	if _last_active_pos != Vector2i(-1, -1):
		var old_cell = board.cells[_last_active_pos.x][_last_active_pos.y]
		old_cell.set_active(false)
	if pos != Vector2i(-1, -1):
		var new_cell = board.cells[pos.x][pos.y]
		new_cell.set_active(true)
	_last_active_pos = pos

# -------------------- Интерфейс и подсветка --------------------
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

func can_pass() -> bool:
	return not has_placed_this_turn and moves_in_round >= 2

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

func reset_cell_colors():
	for row in board.cells:
		for cell in row:
			if cell.is_white():
				cell.sprite.modulate = Color(1, 1, 1, 0.8)
			else:
				cell.sprite.modulate = Color(0.2, 0.2, 0.2, 0.8)

func highlight_available_cells():
	reset_cell_colors()
	if current_phase != Game.GamePhase.CHAIN_BUILDING:
		return
	var available = get_available_cells()
	for cell in available:
		cell.sprite.modulate = Color.YELLOW

func get_available_cells() -> Array[Cell]:
	var result: Array[Cell] = []
	if last_cell_pos == Vector2i(-1, -1):
		if round_number == 1:
			var start_positions = get_start_positions_for_player(active_player_id)
			for pos in start_positions:
				var cell = board.cells[pos.x][pos.y] as Cell
				if cell.is_empty():
					result.append(cell)
		else:
			var has_enemy_gear = false
			for row in board.cells:
				for cell in row:
					if cell.occupied_gear and not cell.occupied_gear.is_owned_by(active_player_id):
						has_enemy_gear = true
						break
				if has_enemy_gear:
					break
			if has_enemy_gear:
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
				result = candidates
			else:
				for row in board.cells:
					for cell in row:
						if cell.is_empty():
							if (active_player_id == 0 and cell.is_white()) or (active_player_id == 1 and cell.is_black()):
								result.append(cell)
		return result
	
	var neighbors = [
		Vector2i(last_cell_pos.x + 1, last_cell_pos.y),
		Vector2i(last_cell_pos.x - 1, last_cell_pos.y),
		Vector2i(last_cell_pos.x, last_cell_pos.y + 1),
		Vector2i(last_cell_pos.x, last_cell_pos.y - 1)
	]
	for n in neighbors:
		if n.x < 0 or n.x >= Game.BOARD_SIZE or n.y < 0 or n.y >= Game.BOARD_SIZE:
			continue
		var cell = board.cells[n.x][n.y] as Cell
		var color_ok = (active_player_id == 0 and cell.is_white()) or (active_player_id == 1 and cell.is_black())
		if not color_ok:
			continue
		if cell.is_empty():
			result.append(cell)
			continue
		if cell.occupied_gear.is_owned_by(active_player_id):
			var has_direct_edge = chain_graph[last_cell_pos].has(n)
			if not has_direct_edge:
				result.append(cell)
	return result

func highlight_chain_cells():
	for row in board.cells:
		for cell in row:
			cell.set_highlighted(false)
	for pos in chain_graph.keys():
		var cell = board.cells[pos.x][pos.y]
		cell.set_highlighted(true)

# -------------------- Обработка действий UI --------------------
func _on_hand_gear_selected(gear: Gear):
	if selected_gear:
		ui.unhighlight_gear(selected_gear)
	selected_gear = gear
	ui.highlight_gear(gear)
	GameLogger.debug("Gear selected from hand")

func _on_action_button_pressed():
	match current_phase:
		Game.GamePhase.CHAIN_BUILDING:
			if has_placed_this_turn:
				active_player_id = 1 - active_player_id
				has_placed_this_turn = false
				if get_available_cells().is_empty():
					GameLogger.info("Player %d has no available moves. Chain ends." % (active_player_id + 1))
					end_chain_building()
				else:
					GameLogger.info("Turn passed to player %d" % (active_player_id + 1))
				update_ui()
			else:
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
			# ничего не делаем
			pass
