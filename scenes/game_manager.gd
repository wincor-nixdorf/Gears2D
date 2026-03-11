# game_manager.gd
class_name GameManager
extends Node

static var ref: GameManager = null

@onready var board: Node2D = $Board
@onready var ui: UI = $UI

var board_manager: BoardManager
var round_manager: RoundManager
var ability_dispatcher: AbilityDispatcher
var players: Array[Player] = []
var phase_machine: PhaseMachine
var game_state: GameState

const PLAYER_SCENE = preload("res://scenes/Player.tscn")
const GEAR_SCENE = preload("res://scenes/Gear.tscn")

# -------------------- Инициализация --------------------
func _ready():
	ref = self
	game_state = GameState  # ссылка на автозагруженный синглтон
	board_manager = BoardManager.new(board)
	phase_machine = PhaseMachine.new(self, game_state)  # передаем game_state
	round_manager = RoundManager.new(self, game_state)  # исправлено: передаем game_state
	ability_dispatcher = AbilityDispatcher.new(self, game_state, EventBus)
	initialize_game()
	ui.action_pressed.connect(_on_action_button_pressed)
	ui.hand_gear_selected.connect(_on_hand_gear_selected)
	# Передаём ссылку на game_manager в UI
	ui.set_game_manager(self)
	# Подключаемся к сигналу клика по игроку
	EventBus.player_clicked.connect(_on_player_clicked)
	GameLogger.info("GameManager ready")

func initialize_game():
	game_state.reset()
	
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
	player1.set_game_manager(self)  # добавлено
	player1.draw_starting_hand(Game.START_HAND_SIZE)
	player2.player_id = 1
	player2.owner_id = 1
	player2.deck = deck2
	player2.set_game_manager(self)  # добавлено
	player2.draw_starting_hand(Game.START_HAND_SIZE)
	add_child(player1)
	add_child(player2)
	players = [player1, player2]
	
	board.generate_board()
	for row in board.cells:
		for cell in row:
			cell.clicked.connect(_on_cell_clicked)
	
	round_manager.start_round()
	GameLogger.info("Game initialized")

# -------------------- Методы доступа --------------------
func get_players() -> Array:
	return players

func get_board_manager() -> BoardManager:
	return board_manager

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
		GameEnums.AbilityID.SPARK:
			script_path = "res://resources/abilities/spark_ability.gd"
		_:
			return null
	
	var script = load(script_path)
	if script:
		var ability = script.new() as Ability
		ability.init(self, game_state.effect_system, EventBus)
		return ability
	else:
		GameLogger.error("Could not load ability script: " + script_path)
		return null

# -------------------- Управление статическими эффектами --------------------
func register_static_effect(gear: Gear, ability: Ability):
	var ctx = {"source_gear": gear}
	ability.execute(ctx)
	EventBus.static_effect_registered.emit(gear, ability)
	GameLogger.debug("Activated static effect: " + ability.ability_name + " for gear " + gear.gear_name)

func unregister_gear_effects(gear: Gear):
	game_state.effect_system.remove_modifiers_from_source(gear)
	EventBus.static_effect_unregistered.emit(gear, null)
	GameLogger.debug("Unregistered static effect for gear")

# -------------------- Управление использованием способностей --------------------
func clear_used_abilities():
	game_state.used_abilities_on_gear.clear()

func is_ability_used_on_gear(gear: Gear, ability_id: int) -> bool:
	var dict = game_state.used_abilities_on_gear.get(gear)
	return dict != null and dict.has(ability_id)

func mark_ability_used_on_gear(gear: Gear, ability_id: int):
	if not game_state.used_abilities_on_gear.has(gear):
		game_state.used_abilities_on_gear[gear] = {}
	game_state.used_abilities_on_gear[gear][ability_id] = true

# -------------------- Управление фазами --------------------
func end_chain_building():
	phase_machine.change_phase(Game.GamePhase.UPTURN)
	GameLogger.info("Chain building phase ended. Starting upturn phase.")
	update_ui()

func end_upturn():
	phase_machine.change_phase(Game.GamePhase.CHAIN_RESOLUTION)
	GameLogger.info("Upturn phase ended. Starting chain resolution.")
	update_ui()

func end_chain_resolution():
	round_manager.end_chain_resolution()

func end_game(winner_id: int):
	round_manager.end_game(winner_id)

# -------------------- Методы, вызываемые из фаз и команд --------------------
func place_gear_from_hand(cell: Cell, player: Player) -> bool:
	if not game_state.selected_gear:
		GameLogger.warning("No gear selected")
		return false
	if not game_state.selected_gear.is_owned_by(player.owner_id) or not (game_state.selected_gear in player.hand):
		GameLogger.warning("Wrong gear selected")
		game_state.selected_gear = null
		ui.clear_selection()
		return false
	
	var success = board_manager.place_gear(game_state.selected_gear, cell.board_pos)
	if not success:
		return false
	
	player.remove_from_hand(game_state.selected_gear)
	game_state.selected_gear.set_cell_size(Game.CELL_SIZE, Game.CELL_INDENT)
	
	game_state.selected_gear.rotated.connect(_on_gear_rotated)
	game_state.selected_gear.triggered.connect(_on_gear_triggered)
	game_state.selected_gear.destroyed.connect(_on_gear_destroyed)
	game_state.selected_gear.clicked.connect(_on_gear_clicked)
	game_state.selected_gear.mouse_entered.connect(_on_gear_mouse_entered)
	game_state.selected_gear.mouse_exited.connect(_on_gear_mouse_exited)
	
	EventBus.gear_placed.emit(game_state.selected_gear, cell)
	
	var placed_gear = game_state.selected_gear
	game_state.selected_gear = null
	ui.clear_selection()
	GameLogger.debug("Gear '%s' placed on board at %s" % [placed_gear.gear_name, Game.pos_to_chess(cell.board_pos)])
	return true

func add_edge(from_pos: Vector2i, to_pos: Vector2i):
	if from_pos == to_pos:
		GameLogger.error("Attempted to add edge from cell to itself: %s" % Game.pos_to_chess(from_pos))
		return
	var edge_id = game_state.chain_graph.add_edge(from_pos, to_pos)
	EventBus.chain_built.emit(game_state.chain_graph.to_dict())
	GameLogger.debug("Added edge %d between %s and %s" % [edge_id, Game.pos_to_chess(from_pos), Game.pos_to_chess(to_pos)])

func get_start_positions_for_player(player: int) -> Array[Vector2i]:
	return board_manager.get_start_positions_for_player(player)

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

func on_successful_placement():
	game_state.has_placed_this_turn = true
	game_state.moves_in_round += 1
	update_ui()

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

func set_active_cell(pos: Vector2i):
	if game_state.last_active_pos != Vector2i(-1, -1):
		board_manager.set_cell_active(game_state.last_active_pos, false)
	if pos != Vector2i(-1, -1):
		board_manager.set_cell_active(pos, true)
	game_state.last_active_pos = pos

func proceed_to_next_cell() -> void:
	if phase_machine.current_phase is ResolutionPhase:
		(phase_machine.current_phase as ResolutionPhase).proceed_to_next_cell()
	else:
		GameLogger.error("proceed_to_next_cell called but current phase is not ResolutionPhase")

func restart_chain_resolution() -> void:
	if phase_machine.current_phase is ResolutionPhase:
		(phase_machine.current_phase as ResolutionPhase).restart_chain_resolution()
	else:
		GameLogger.error("restart_chain_resolution called but current phase is not ResolutionPhase")

# -------------------- Обработка сигналов от шестерней и UI --------------------
func _on_gear_clicked(gear: Gear):
	print("=== GameManager._on_gear_clicked: ", gear.gear_name)
	if ui.is_target_selection_active():
		if ui.is_valid_target(gear):
			print("   Emitting target_selected for gear")
			EventBus.target_selected.emit(gear)
		return
	phase_machine.handle_gear_clicked(gear)

func _on_gear_mouse_entered(gear: Gear):
	if gear.is_owned_by(game_state.active_player_id):
		ui.show_gear_tooltip(gear, get_viewport().get_mouse_position())

func _on_gear_mouse_exited(_gear: Gear):
	ui.hide_gear_tooltip()

func _on_gear_rotated(gear: Gear, old_ticks: int, new_ticks: int):
	update_ui()
	EventBus.gear_rotated.emit(gear, old_ticks, new_ticks)

func _on_gear_triggered(gear: Gear):
	for ability in gear.abilities:
		if ability.ability_type == GameEnums.AbilityType.STATIC:
			if not is_ability_used_on_gear(gear, ability.ability_id):
				register_static_effect(gear, ability)
				mark_ability_used_on_gear(gear, ability.ability_id)
	
	EventBus.gear_triggered.emit(gear)
	update_ui()

func _on_gear_destroyed(gear: Gear):
	var cell = gear.get_parent() as Cell
	if cell:
		board_manager.clear_gear(cell.board_pos)
		game_state.chain_graph.remove_vertex(cell.board_pos)
		# ... остальная логика ...
	
	game_state.effect_system.remove_modifiers_from_target(gear)
	unregister_gear_effects(gear)
	
	EventBus.gear_destroyed.emit(gear)
	EventBus.chain_built.emit(game_state.chain_graph.to_dict())
	update_ui()
	_check_state_based_actions()

func _on_hand_gear_selected(gear: Gear):
	if game_state.selected_gear:
		ui.unhighlight_gear(game_state.selected_gear)
	game_state.selected_gear = gear
	ui.highlight_gear(gear)
	GameLogger.debug("Gear selected from hand")

func _on_cell_clicked(cell: Cell):
	print("=== GameManager._on_cell_clicked: cell ", Game.pos_to_chess(cell.board_pos))
	if ui.is_target_selection_active():
		var target = cell.occupied_gear if cell.occupied_gear else cell
		if ui.is_valid_target(target):
			print("   Emitting target_selected for target: ", target)
			EventBus.target_selected.emit(target)
		return
	phase_machine.handle_cell_clicked(cell)

func _on_player_clicked(player: Player):
	print("=== GameManager._on_player_clicked: ", player.player_id)
	if ui.is_target_selection_active():
		if ui.is_valid_target(player):
			EventBus.target_selected.emit(player)
		return
	phase_machine.handle_player_clicked(player)

func _on_action_button_pressed():
	phase_machine.handle_action_button()

# -------------------- Проверки состояния (SBA) --------------------
func _check_state_based_actions():
	var actions_taken = false
	for gear in board_manager.get_all_gears():
		if gear.current_ticks <= -gear.max_tocks:
			gear.destroy()
			actions_taken = true
			continue
		if gear.current_ticks >= gear.max_ticks and not gear.is_triggered:
			var prevented = game_state.effect_system.has_modifier(gear, "prevent_trigger")
			if not prevented:
				gear.trigger()
			else:
				game_state.effect_system.remove_modifier_by_tag(gear, "prevent_trigger")
				GameLogger.debug("Trigger prevented by Mana Leak")
			actions_taken = true
	if actions_taken:
		_check_state_based_actions()

# -------------------- Интерфейс и подсветка --------------------
func update_ui():
	# Если активен выбор цели, не обновляем интерфейс,
	# чтобы не сбросить промпт и подсветку целей
	if ui.is_target_selection_active():
		return
	
	ui.update_player(game_state.active_player_id)
	ui.update_phase(game_state.current_phase)
	ui.update_t_pool(game_state.t_pool[0], game_state.t_pool[1])
	ui.update_action_button(game_state.current_phase, game_state.has_placed_this_turn, game_state.active_player_id, can_pass())
	ui.update_hands(players[0].hand, players[1].hand, game_state.active_player_id)
	ui.update_round(game_state.round_number)
	ui.update_chain_length(game_state.chain_graph.size())
	ui.update_prompt(get_prompt_text())
	ui.update_damage(players[0].damage, players[1].damage)
	highlight_available_cells()
	board_manager.reset_chain_highlights()
	highlight_chain_cells()

func get_prompt_text() -> String:
	# Если активен выбор цели, не меняем промпт (он уже установлен UI)
	if ui.is_target_selection_active():
		return ""
	
	var player_num = game_state.active_player_id + 1
	match game_state.current_phase:
		Game.GamePhase.CHAIN_BUILDING:
			if game_state.last_cell_pos == Vector2i(-1, -1):
				return "Player %d: Select a starting cell and a gear from hand" % player_num
			elif not game_state.has_placed_this_turn:
				if game_state.moves_in_round < 2:
					return "Player %d: You must make a move (continue the chain)" % player_num
				else:
					return "Player %d: You can make a move or press Pass" % player_num
			else:
				return "Player %d: You can take T from the last gear in the chain (click on it) or press End Turn" % player_num
		Game.GamePhase.UPTURN:
			return "Player %d: Click on an opponent's gear to peek for 1 T or press End Peek" % player_num
		Game.GamePhase.CHAIN_RESOLUTION:
			if game_state.waiting_for_player:
				return "Player %d: Click on current gear for an extra tick for 1 T or press Skip" % player_num
			else:
				return "Resolving chain..."
		Game.GamePhase.RENEWAL:
			return "Renewal..."
		_:
			return ""

func highlight_available_cells():
	board_manager.reset_highlights()
	if game_state.current_phase != Game.GamePhase.CHAIN_BUILDING:
		return
	var available = get_available_cells()
	for cell in available:
		cell.sprite.modulate = Color.YELLOW

func highlight_chain_cells():
	for pos in game_state.chain_graph.get_vertices():
		board_manager.set_cell_highlighted(pos, true)
