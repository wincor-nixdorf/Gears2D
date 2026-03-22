# spark_ability.gd
extends Ability

func _init() -> void:
	ability_id = GameEnums.AbilityID.SPARK
	ability_name = "Spark"
	target_type = GameEnums.TargetType.ANY
	description = "Deal 1 damage to any target."

func execute(context: Dictionary) -> void:
	var source = context.get("source_gear") as Gear
	var target = context.get("target")
	if not source or not target:
		return
	
	if target is Player:
		target.damage += 1
		GameLogger.info("Spark deals 1 damage to Player %d" % (target.player_id + 1))
		return
	
	if target is Gear:
		# Spark не может нацеливаться на Interrupt
		if target.type == GameEnums.GearType.INTERRUPT:
			GameLogger.debug("Spark cannot target Interrupt gear %s" % target.gear_name)
			return
		
		if target.is_face_up:
			# AG: только существа получают урон
			if target.type == GameEnums.GearType.CREATURE:
				target.take_damage(1)
				GameLogger.debug("Spark deals 1 damage to creature %s" % target.gear_name)
			else:
				# Routine или Tuning AG не получают урон
				GameLogger.debug("Spark cannot damage non-creature AG %s" % target.gear_name)
		else:
			# DG: наносим tock
			await target.do_tock(1)
			GameLogger.debug("Spark causes tock on DG %s" % target.gear_name)

func get_possible_targets(context: Dictionary) -> Array:
	var source = context.get("source_gear") as Gear
	if not source:
		return []
	
	var result = []
	
	# Добавляем обоих игроков
	for player in game_manager.get_players():
		result.append(player)
	
	# Добавляем все шестерни на доске
	for gear in game_manager.get_board_manager().get_all_gears():
		# Нельзя выбрать себя
		if gear == source:
			continue
		
		# Нельзя выбрать Interrupt
		if gear.type == GameEnums.GearType.INTERRUPT:
			continue
		
		# DG можно всегда
		if not gear.is_face_up:
			result.append(gear)
			continue
		
		# AG: только существа
		if gear.type == GameEnums.GearType.CREATURE:
			result.append(gear)
		# Routine и Tuning AG не добавляем
	
	GameLogger.debug("Spark possible targets for %s: %d" % [source.gear_name, result.size()])
	return result
