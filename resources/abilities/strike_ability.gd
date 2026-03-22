# strike_ability.gd
extends Ability

func _init() -> void:
	ability_id = GameEnums.AbilityID.STRIKE
	ability_name = "Strike"
	target_type = GameEnums.TargetType.GEAR
	description = "Deal damage equal to this creature's Impact to target creature."

func execute(context: Dictionary) -> void:
	var source = context.get("source_gear") as Gear
	var target = context.get("target") as Gear
	
	if not source or not target:
		GameLogger.error("StrikeAbility: missing source or target")
		return
	
	# Проверка, что источник - AG существо
	if not source.is_face_up or source.type != GameEnums.GearType.CREATURE:
		GameLogger.warning("StrikeAbility: source is not an active creature")
		return
	
	var damage = source.impact
	
	# Нанесение урона
	target.take_damage(damage)
	
	GameLogger.info("%s strikes %s for %d damage" % [source.gear_name, target.gear_name, damage])

func get_possible_targets(context: Dictionary) -> Array:
	var source = context.get("source_gear") as Gear
	if not source:
		return []
	
	var targets: Array = []
	
	# Существо может атаковать только соседние клетки (ортогонально)
	for neighbor_pos in game_manager.board_manager.get_neighbors(source.board_position):
		var target_gear = game_manager.board_manager.get_gear_at(neighbor_pos)
		if target_gear and target_gear.owner_id != source.owner_id:
			# Можно атаковать только AG существа
			if target_gear.is_face_up and target_gear.type == GameEnums.GearType.CREATURE:
				targets.append(target_gear)
	
	GameLogger.debug("Strike possible targets for %s at %s: %d" % [source.gear_name, Game.pos_to_chess(source.board_position), targets.size()])
	return targets
