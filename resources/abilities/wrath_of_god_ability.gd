# wrath_of_god_ability.gd
extends Ability

func _init():
	ability_id = GameEnums.AbilityID.WRATH_OF_GOD
	ability_name = "Wrath Of God"
	ability_type = GameEnums.AbilityType.TRIGGERED
	trigger = GameEnums.TriggerCondition.ON_TRIGGER
	description = "When triggered, destroy all gears in the current chain."

func execute(context: Dictionary):
	var source = context.get("source_gear") as Gear
	if not source:
		return
	
	var board_manager = game_manager.get_board_manager()
	var chain_graph = game_manager.game_state.chain_graph
	
	# Получаем все позиции в текущей цепочке
	var chain_positions = chain_graph.get_vertices()
	
	# Уничтожаем все G на этих позициях
	for pos in chain_positions:
		var gear = board_manager.get_gear_at(pos)
		if gear:
			gear.destroy()
	
	GameLogger.info("Wrath Of God destroyed all gears in the current chain")
