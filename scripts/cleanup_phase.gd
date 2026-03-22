# cleanup_phase.gd
class_name CleanupPhase
extends Phase

func enter() -> void:
	GameLogger.debug("CleanupPhase: enter")
	
	# 1. Активный игрок (Starter) сбрасывает руку до максимального размера
	var starter_player = game_manager.players[game_state.start_player_id]
	while starter_player.hand.size() > Game.MAX_HAND_SIZE:
		var gear = starter_player.hand.pop_back()
		gear.queue_free()
		EventBus.hand_updated.emit(starter_player.player_id, starter_player.hand)
	GameLogger.debug("CleanupPhase: player %d hand size now %d" % [game_state.start_player_id, starter_player.hand.size()])
	
	# 2. Прекращаются эффекты "до конца хода"
	for gear in board_manager.get_all_gears():
		if game_state.effect_system.has_modifier(gear, "until_end_of_turn"):
			game_state.effect_system.remove_modifier_by_tag(gear, "until_end_of_turn")
	
	# 3. Наносим урон от T-пула
	for i in [0, 1]:
		var damage = game_state.t_pool[i]
		if damage > 0:
			game_manager.players[i].damage += damage
			game_state.t_pool[i] = 0
			GameLogger.info("Player %d takes %d damage from T pool, total damage: %d" % [i + 1, damage, game_manager.players[i].damage])
	EventBus.t_pool_updated.emit(game_state.t_pool[0], game_state.t_pool[1])
	
	# 4. Сбрасываем счётчики предотвращений (Mana Leak) на новый раунд
	game_state.effect_system.clear_prevent_counts()
	
	# 5. Сбрасываем повреждения на всех G на доске
	for gear in board_manager.get_all_gears():
		gear.damage_taken = 0
		if gear.has_method("update_damage_label"):
			gear.update_damage_label()
	
	# 6. Проверяем условия победы
	for p in game_manager.players:
		if p.damage >= Game.MAX_DAMAGE:
			game_manager.end_game(p.player_id)
			return
	
	# 7. Подготавливаем данные для следующего раунда
	game_state.active_player_id = 1 - game_state.start_player_id
	game_state.round_number += 1
	game_state.consecutive_passes = 0
	game_state.start_player_id = game_state.active_player_id
	EventBus.player_changed.emit(game_state.active_player_id)
	GameLogger.info("=== Starting Round %d. Active player: %d ===" % [game_state.round_number, game_state.active_player_id + 1])
	
	# Сбрасываем граф цепочки и визуальные элементы
	game_state.chain_graph.clear()
	board_manager.clear_chain_visuals()
	game_state.last_cell_pos = Vector2i(-1, -1)
	game_state.last_from_pos = Vector2i(-1, -1)
	game_state.has_placed_this_turn = false
	game_state.moves_in_round = 0
	game_state.selected_gear = null
	game_state.selected_creature = null
	game_manager.ui.clear_selection()
	
	# 8. Переходим к следующему раунду с фазы Upkeep
	game_manager.phase_machine.call_deferred("change_phase", Game.GamePhase.UPKEEP)

func exit() -> void:
	GameLogger.debug("CleanupPhase: exit")
	super()

func handle_cell_clicked(cell: Cell) -> void:
	pass

func handle_gear_clicked(gear: Gear, button_index: int) -> void:
	pass

func handle_player_clicked(player: Player) -> void:
	pass

func handle_action_button() -> void:
	pass
