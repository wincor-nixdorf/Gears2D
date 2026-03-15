# spark_ability.gd
extends Ability

func _init() -> void:
	ability_id = GameEnums.AbilityID.SPARK
	ability_name = "Spark"
	target_type = GameEnums.TargetType.ANY
	description = "Deal 1 damage to any target: player, face-down gear (tock), or creature (damage)."

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
		if target.is_face_up:
			# Если это существо (type == CREATURE) или любая другая G лицом вверх, наносим урон
			target.take_damage(1)
			GameLogger.debug("Spark deals 1 damage to gear %s (total damage %d/%d)" % [target.gear_name, target.damage_taken, target.max_ticks + target.max_tocks])
		else:
			await target.do_tock(1)
			GameLogger.debug("Spark causes tock on gear %s" % target.gear_name)

func get_possible_targets(context: Dictionary) -> Array:
	var source = context.get("source_gear") as Gear
	if not source:
		return []
	
	var result = []
	
	# Добавляем обоих игроков
	result.append_array(game_manager.get_players())
	
	# Добавляем все шестерни на доске
	for gear in game_manager.get_board_manager().get_all_gears():
		# Если шестерня лицом вниз — разрешена
		if not gear.is_face_up:
			result.append(gear)
			continue
		# Если шестерня лицом вверх и является существом (type == CREATURE) — разрешена
		if gear.is_face_up and gear.type == GameEnums.GearType.CREATURE:
			result.append(gear)
	
	return result
