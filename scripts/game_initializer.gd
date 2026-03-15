# game_initializer.gd (полный код с использованием AbilitySlotData)
class_name GameInitializer
extends RefCounted

var game_manager: GameManager
var board: Node2D
var players_scene = preload("res://scenes/Player.tscn")
var gear_scene = preload("res://scenes/Gear.tscn")

# Словарь для кеширования способностей по ID
var abilities_by_id: Dictionary = {}

func _init(gm: GameManager, board_node: Node2D):
	game_manager = gm
	board = board_node

func initialize_game() -> void:
	var deck_data = load_decks_from_json("res://data/gears.json")
	var deck1: Array[GearData] = deck_data.duplicate()
	var deck2: Array[GearData] = deck_data.duplicate()
	deck1.shuffle()
	deck2.shuffle()
	
	var player1 = players_scene.instantiate()
	var player2 = players_scene.instantiate()
	player1.player_id = 0
	player1.owner_id = 0
	player1.deck = deck1
	player1.set_game_manager(game_manager)
	player1.draw_starting_hand(Game.START_HAND_SIZE)
	player2.player_id = 1
	player2.owner_id = 1
	player2.deck = deck2
	player2.set_game_manager(game_manager)
	player2.draw_starting_hand(Game.START_HAND_SIZE)
	game_manager.add_child(player1)
	game_manager.add_child(player2)
	game_manager.players = [player1, player2]
	
	board.generate_board()
	for row in board.cells:
		for cell in row:
			cell.clicked.connect(game_manager.event_handler._on_cell_clicked)
	
	GameLogger.info("Game initialized")

func load_decks_from_json(path: String) -> Array[GearData]:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		GameLogger.error("Cannot open JSON file: " + path)
		return []
	var text = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(text)
	if error != OK:
		GameLogger.error("JSON parse error: " + json.get_error_message())
		return []
	var data = json.data
	var result: Array[GearData] = []
	for entry in data:
		var gd = GearData.new()
		gd.gear_name = entry.get("name", "Unknown")
		
		var super_str = entry.get("supertype", "")
		match super_str:
			"Legendary":
				gd.supertype = GameEnums.GearSupertype.LEGENDARY
			_:
				gd.supertype = GameEnums.GearSupertype.NONE
		
		var type_str = entry.get("type", "Routine")
		match type_str:
			"Creature":
				gd.type = GameEnums.GearType.CREATURE
			"Tuning":
				gd.type = GameEnums.GearType.TUNING
			_:
				gd.type = GameEnums.GearType.ROUTINE
		
		var sub_str = entry.get("subtype", "")
		match sub_str:
			"Gearling":
				gd.subtype = GameEnums.GearSubtype.GEARLING
			"Golem":
				gd.subtype = GameEnums.GearSubtype.GOLEM
			"Gremlin":
				gd.subtype = GameEnums.GearSubtype.GREMLIN
			"Goblin":
				gd.subtype = GameEnums.GearSubtype.GOBLIN
			"Giant":
				gd.subtype = GameEnums.GearSubtype.GIANT
			"Pirate", "Gangster":
				gd.subtype = GameEnums.GearSubtype.GANGSTER
			"Gutterborn":
				gd.subtype = GameEnums.GearSubtype.GUTTERBORN
			_:
				gd.subtype = GameEnums.GearSubtype.NONE
		
		gd.speed = entry.get("speed", 0)
		gd.is_flying = entry.get("is_flying", false)
		
		var reverse_path = entry.get("texture_reverse", "")
		var obverse_path = entry.get("texture_obverse", "")
		if reverse_path:
			gd.texture_reverse = load(reverse_path)
		if obverse_path:
			gd.texture_obverse = load(obverse_path)
		gd.max_ticks = entry.get("max_ticks", 3)
		gd.max_tocks = entry.get("max_tocks", 2)
		
		var ability_slots_data = entry.get("ability_slots", [])
		gd.ability_slots.clear()
		for slot_data in ability_slots_data:
			var slot = AbilitySlotData.new()
			slot.ability_id = slot_data.get("ability_id", -1)
			slot.type = slot_data.get("type", 0)
			slot.cost = slot_data.get("cost", 0)
			slot.trigger = slot_data.get("trigger", -1)
			gd.ability_slots.append(slot)
		
		result.append(gd)
	return result

func get_ability_by_id(id: int) -> Ability:
	if abilities_by_id.has(id):
		return abilities_by_id[id]
	var ability = create_ability_by_id(id)
	if ability:
		abilities_by_id[id] = ability
	return ability

func create_ability_by_id(id: int) -> Ability:
	var script_path = ""
	match id:
		GameEnums.AbilityID.SPRING:
			script_path = "res://resources/abilities/boomerang_ability.gd"
		GameEnums.AbilityID.TIME_SWARM:
			script_path = "res://resources/abilities/time_swarm_ability.gd"
		GameEnums.AbilityID.REPEAT:
			script_path = "res://resources/abilities/repeat_ability.gd"
		GameEnums.AbilityID.MANA_LEAK:
			script_path = "res://resources/abilities/mana_leak_ability.gd"
		GameEnums.AbilityID.SPARK:
			script_path = "res://resources/abilities/spark_ability.gd"
		GameEnums.AbilityID.WRATH_OF_GOD:
			script_path = "res://resources/abilities/wrath_of_god_ability.gd"
		GameEnums.AbilityID.UPHEAVAL:
			script_path = "res://resources/abilities/upheaval_ability.gd"
		GameEnums.AbilityID.ACTIVATED_SPARK:
			script_path = "res://resources/abilities/spark_ability.gd"
		_:
			return null
	
	var script = load(script_path)
	if script:
		var ability = script.new() as Ability
		ability.init(game_manager, game_manager.game_state.effect_system, EventBus, game_manager.stack_manager)
		return ability
	else:
		GameLogger.error("Could not load ability script: " + script_path)
		return null
