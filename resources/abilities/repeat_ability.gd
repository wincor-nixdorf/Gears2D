# repeat_ability.gd
extends Ability

func _init():
	ability_id = GameEnums.AbilityID.REPEAT
	ability_name = "Repeat"
	description = "If this ability hasn't been used this round, restart chain resolution from the last placed gear."

func execute(context: Dictionary) -> void:
	var gear = context.get("source_gear") as Gear
	if not gear:
		return
	
	var gm = game_manager
	if gm.is_ability_used_on_gear(gear, self.ability_id):
		GameLogger.debug("Repeat already used on this gear this round, ignoring")
		return
	
	gm.mark_ability_used_on_gear(gear, self.ability_id)
	
	# Перезапуск цепочки может быть асинхронным, поэтому ждём
	await gm.restart_chain_resolution()
