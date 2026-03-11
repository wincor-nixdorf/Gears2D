# spark_ability.gd
extends Ability

func _init():
	ability_id = GameEnums.AbilityID.SPARK
	ability_name = "Spark"
	ability_type = GameEnums.AbilityType.TRIGGERED
	trigger = GameEnums.TriggerCondition.ON_TRIGGER
	target_type = GameEnums.TargetType.ANY
	description = "Deal 1 damage to any target: player, face-down gear (tock), or face-up gear (damage)."

func execute(context: Dictionary) -> void:
	var source = context.get("source_gear") as Gear
	var target = context.get("target")
	if not source or not target:
		return
	
	if target is Player:
		target.damage += 1
		GameLogger.info("Spark deals 1 damage to Player %d" % (target.player_id + 1))
		game_manager.update_ui()
		return
	
	if target is Gear:
		if target.is_face_up:
			target.take_damage(1)
			GameLogger.debug("Spark deals 1 damage to gear %s (total damage %d/%d)" % [target.gear_name, target.damage_taken, target.max_ticks + target.max_tocks])
		else:
			print("Spark: about to call do_tock on ", target.gear_name)
			await target.do_tock(1)
			print("Spark: do_tock finished on ", target.gear_name)
			GameLogger.debug("Spark causes tock on gear %s" % target.gear_name)
		game_manager.update_ui()

func get_possible_targets(context: Dictionary) -> Array:
	var source = context.get("source_gear") as Gear
	if not source:
		return []
	
	var result = []
	result.append_array(game_manager.get_players())
	result.append_array(game_manager.get_board_manager().get_all_gears())
	return result
