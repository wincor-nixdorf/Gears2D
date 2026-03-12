# mana_leak_ability.gd
extends Ability

func _init():
	ability_id = GameEnums.AbilityID.MANA_LEAK
	ability_name = "Mana Leak"
	ability_type = GameEnums.AbilityType.TRIGGERED
	trigger = GameEnums.TriggerCondition.ON_TRIGGER
	description = "When triggered, prevent the next trigger of an enemy gear."

func execute(context: Dictionary):
	var source = context.get("source_gear") as Gear
	if not source:
		return
	# Добавляем одно предотвращение для владельца source (т.е. для его противника)
	# Счётчик хранится по owner_id владельца способности – при проверке мы будем смотреть enemy_id.
	# Увеличиваем счётчик для source.owner_id – это означает, что следующий триггер врага (enemy_id = 1 - source.owner_id) будет предотвращён.
	game_manager.game_state.prevented_triggers[source.owner_id] = game_manager.game_state.prevented_triggers.get(source.owner_id, 0) + 1
	GameLogger.debug("Mana Leak activated, will prevent next enemy trigger")
