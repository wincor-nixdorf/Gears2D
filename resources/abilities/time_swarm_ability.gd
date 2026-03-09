extends Ability

func _init():
	ability_id = GameEnums.AbilityID.TIME_SWARM
	ability_name = "Time Swarm"
	ability_type = GameEnums.AbilityType.STATIC
	description = "All enemy gears do not make automatic tick during resolution."

func execute(context: Dictionary):
	var source_gear = context.get("source_gear") as Gear
	if not source_gear:
		return
	
	# Добавляем модификатор "no_auto_tick" на все текущие вражеские шестерни
	for enemy_gear in GameManager.ref.board_manager.get_all_gears():
		if enemy_gear.owner_id != source_gear.owner_id:
			GameState.effect_system.add_modifier(enemy_gear, source_gear, "no_auto_tick")
	
	# Помечаем, что эта шестерня является источником Time Swarm (для будущих размещений)
	# Можно добавить модификатор на самого себя, чтобы потом легко найти все источники
	GameState.effect_system.add_modifier(source_gear, source_gear, "time_swarm_source")
	
	GameLogger.debug("Time Swarm activated from gear %s" % source_gear.gear_name)
