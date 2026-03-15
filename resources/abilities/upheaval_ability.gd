# upheaval_ability.gd
extends Ability

func _init():
	ability_id = GameEnums.AbilityID.UPHEAVAL
	ability_name = "Upheaval"
	description = "Flip all face-down gears not in the current chain."

func execute(context: Dictionary) -> void:
	var source = context.get("source_gear") as Gear
	if not source:
		return
	
	var board_manager = game_manager.get_board_manager()
	var chain_graph = game_manager.game_state.chain_graph
	var current_chain_positions = chain_graph.get_vertices()
	var targets = []
	
	for gear in board_manager.get_all_gears():
		if gear == source:
			continue
		if gear.is_face_up:
			continue
		if gear.board_position in current_chain_positions:
			continue
		targets.append(gear)
	
	GameLogger.debug("Upheaval: found %d targets" % targets.size())
	
	# Начинаем пакет с указанием активного игрока (владельца источника)
	game_manager.stack_manager.begin_batch(source.owner_id)
	
	for gear in targets:
		gear.flip()   # внутри flip() вызовет trigger(), который добавит способности в пакет
	
	game_manager.stack_manager.end_batch()
