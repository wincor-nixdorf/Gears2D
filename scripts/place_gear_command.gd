# place_gear_command.gd
class_name PlaceGearCommand
extends GameCommand

var cell: Cell
var player: Player
var gear: Gear

func _init(p_cell: Cell, p_player: Player, p_gear: Gear):
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
	
	# Подключаем сигналы (если они уже были отключены)
	gear._connect_signals()
	
	EventBus.gear_placed.emit(gear, cell)
	
	# Добавляем ресурс T
	GameState.t_pool[GameState.active_player_id] += 1
	EventBus.t_pool_updated.emit(GameState.t_pool[0], GameState.t_pool[1])
	
	# Добавляем вершину в граф (ребро будет добавлено позже в chain_building_phase)
	GameState.chain_graph.add_vertex(cell.board_pos)
	
	# Помечаем, что ход сделан (но last_cell_pos обновится позже)
	GameState.has_placed_this_turn = true
	GameState.moves_in_round += 1
	
	GameLogger.debug("Gear '%s' placed on board at %s" % [gear.gear_name, Game.pos_to_chess(cell.board_pos)])
