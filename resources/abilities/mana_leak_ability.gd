# mana_leak_ability.gd
extends Ability

func _init():
	ability_id = GameEnums.AbilityID.MANA_LEAK
	ability_name = "Mana Leak"
	description = "When triggered, prevent the next trigger of an enemy gear."

func execute(context: Dictionary):
	var source = context.get("source_gear") as Gear
	if not source:
		return
	# Добавляем одно предотвращение для владельца source (т.е. для его противника)
	effect_system.add_prevent(source.owner_id)
	GameLogger.debug("Mana Leak activated, will prevent next enemy trigger")
