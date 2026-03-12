# round_manager.gd
class_name RoundManager
extends RefCounted

var game_manager: GameManager
var game_state: GameState
var board_manager: BoardManager
var phase_machine: PhaseMachine
var ui: UI

func _init(gm: GameManager, gs: GameState):
	game_manager = gm
	game_state = gs
	board_manager = gm.board_manager
	phase_machine = gm.phase_machine
	ui = gm.ui

func start_round():
	game_manager.set_active_cell(Vector2i(-1, -1))
	game_manager.clear_used_abilities()
	game_state.start_player_id = game_state.active_player_id
	GameLogger.info("=== Round %d. Active player: %d ===" % [game_state.round_number, game_state.active_player_id + 1])
	game_state.chain_graph.clear()
	game_state.last_cell_pos = Vector2i(-1, -1)
	game_state.last_from_pos = Vector2i(-1, -1)
	game_state.passed = false
	game_state.has_placed_this_turn = false
	game_state.moves_in_round = 0
	game_state.selected_gear = null
	ui.clear_selection()
	phase_machine.change_phase(Game.GamePhase.CHAIN_BUILDING)
	game_manager.update_ui()

func end_chain_resolution():
	game_manager.set_active_cell(Vector2i(-1, -1))
	phase_machine.change_phase(Game.GamePhase.RENEWAL)
	GameLogger.info("Chain resolution phase ended. Starting renewal.")
	
	# Наносим урон игрокам от их собственного пула T
	for i in [0,1]:
		var damage = game_state.t_pool[i]
		game_manager.players[i].damage += damage
		game_state.t_pool[i] = 0	
		
	EventBus.t_pool_updated.emit(game_state.t_pool[0], game_state.t_pool[1])
	
	# Сбрасываем предотвращения Mana Leak (действуют только в текущем раунде)
	game_state.prevented_triggers.clear()
	
	# Сбрасываем повреждения на всех G на доске
	for gear in game_manager.get_board_manager().get_all_gears():
		gear.damage_taken = 0
		# Обновляем отображение урона, если есть метка
		if gear.has_method("update_damage_label"):
			gear.update_damage_label()
	
	for p in game_manager.players:
		if p.damage >= Game.MAX_DAMAGE:
			end_game(p.player_id)
			return
	
	for p in game_manager.players:
		p.draw_card()
	
	game_state.active_player_id = 1 - game_state.start_player_id
	game_state.round_number += 1
	EventBus.player_changed.emit(game_state.active_player_id)
	start_round()

func end_game(winner_id: int):
	GameLogger.info("Player %d wins!" % (winner_id + 1))
	game_manager.get_tree().paused = true
