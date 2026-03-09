# round_manager.gd
class_name RoundManager
extends RefCounted

var game_manager: GameManager
var board_manager: BoardManager
var phase_machine: PhaseMachine
var ui: UI

func _init(gm: GameManager):
	game_manager = gm
	board_manager = gm.board_manager
	phase_machine = gm.phase_machine
	ui = gm.ui

func start_round():
	game_manager.set_active_cell(Vector2i(-1, -1))
	game_manager.clear_used_abilities()
	GameState.start_player_id = GameState.active_player_id
	GameLogger.info("=== Round %d. Active player: %d ===" % [GameState.round_number, GameState.active_player_id + 1])
	GameState.chain_graph.clear()
	GameState.last_cell_pos = Vector2i(-1, -1)
	GameState.last_from_pos = Vector2i(-1, -1)
	GameState.passed = false
	GameState.has_placed_this_turn = false
	GameState.moves_in_round = 0
	GameState.selected_gear = null
	ui.clear_selection()
	phase_machine.change_phase(Game.GamePhase.CHAIN_BUILDING)
	game_manager.update_ui()

func end_chain_resolution():
	game_manager.set_active_cell(Vector2i(-1, -1))
	phase_machine.change_phase(Game.GamePhase.RENEWAL)
	GameLogger.info("Chain resolution phase ended. Starting renewal.")
	for i in [0,1]:
		var damage = GameState.t_pool[i]
		game_manager.players[1-i].damage += damage
		GameState.t_pool[i] = 0
	EventBus.t_pool_updated.emit(GameState.t_pool[0], GameState.t_pool[1])
	
	for p in game_manager.players:
		if p.damage >= Game.MAX_DAMAGE:
			end_game(p.player_id)
			return
	
	for p in game_manager.players:
		p.draw_card()
	
	GameState.active_player_id = 1 - GameState.start_player_id
	GameState.round_number += 1
	EventBus.player_changed.emit(GameState.active_player_id)
	start_round()

func end_game(winner_id: int):
	GameLogger.info("Player %d wins!" % (winner_id + 1))
	game_manager.get_tree().paused = true
