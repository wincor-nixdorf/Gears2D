# repeat_ability.gd
extends Ability

func _init():
	ability_id = GameEnums.AbilityID.REPEAT
	ability_name = "Repeat"
	ability_type = GameEnums.AbilityType.TRIGGERED
	trigger = GameEnums.TriggerCondition.ON_TRIGGER
	description = "If this ability hasn't been used this round, restart chain resolution from the last placed gear."

func execute(context: Dictionary):
	var gear = context.get("source_gear") as Gear
	if not gear:
		return
	
	var gm = GameManager.ref
	# Проверяем, не использовалась ли уже эта способность на данной G в текущем разрешении
	if gm.is_ability_used_on_gear(gear, self.ability_id):
		GameLogger.debug("Repeat already used on this gear this round, ignoring")
		return
	
	# Помечаем как использованную
	gm.mark_ability_used_on_gear(gear, self.ability_id)
	
	# Перезапускаем разрешение цепочки с последней установленной G
	gm.restart_chain_resolution()
