# place_gear_command.gd
class_name PlaceGearCommand
extends GameCommand

var cell: Cell
var player: Player
var gear: Gear

func _init(p_cell: Cell, p_player: Player, p_gear: Gear, gm: GameManager, gs: GameState) -> void:
	super(gm, gs)
	cell = p_cell
	player = p_player
	gear = p_gear

func can_execute() -> bool:
	if not cell or not player or not gear:
		return false
	if not gear.is_owned_by(player.owner_id) or not (gear in player.hand):
		return false
	if not cell.is_empty():
		return false
	return true

func execute() -> void:
	player.remove_from_hand(gear)
	cell.set_occupied(gear)
	gear.set_cell_size(Game.CELL_SIZE, Game.CELL_INDENT)
	gear.board_position = cell.board_pos
	
	# Подключаем сигналы к event_handler
	if game_manager and game_manager.event_handler:
		gear.rotated.connect(game_manager.event_handler._on_gear_rotated)
		gear.triggered.connect(game_manager.event_handler._on_gear_triggered)
		gear.destroyed.connect(game_manager.event_handler._on_gear_destroyed)
		gear.clicked.connect(game_manager.event_handler._on_gear_clicked)
		gear.mouse_entered.connect(game_manager.event_handler._on_gear_mouse_entered)
		gear.mouse_exited.connect(game_manager.event_handler._on_gear_mouse_exited)
	
	EventBus.gear_placed.emit(gear, cell)
	
	game_state.t_pool[game_state.active_player_id] += 1
	EventBus.t_pool_updated.emit(game_state.t_pool[0], game_state.t_pool[1])
	
	game_state.chain_graph.add_vertex(cell.board_pos)
	
	game_state.has_placed_this_turn = true
	game_state.moves_in_round += 1
	
	GameLogger.debug("Gear '%s' placed on board at %s" % [gear.gear_name, Game.pos_to_chess(cell.board_pos)])
