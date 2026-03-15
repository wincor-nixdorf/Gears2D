# player.gd
class_name Player
extends Node

@export var player_id: int = 0
@export var owner_id: int = 0
@export var damage: int = 0

var deck: Array[GearData] = []          # колода из данных (GearData)
var hand: Array[Gear] = []              # рука из экземпляров Gear
var game_manager: GameManager

const GEAR_SCENE = preload("res://scenes/Gear.tscn")

func set_game_manager(gm: GameManager) -> void:
	game_manager = gm

func _init(pid: int = 0, deck_data: Array[GearData] = []) -> void:
	player_id = pid
	owner_id = pid
	deck = deck_data.duplicate()
	hand = []
	deck.shuffle()

# Берёт одну карту из колоды и добавляет в руку
func draw_card() -> Gear:
	if deck.is_empty():
		return null
	var gear_data = deck.pop_front()
	var gear = GEAR_SCENE.instantiate()
	gear.set_game_manager(game_manager)   # устанавливаем game_manager ПЕРЕД apply_data
	gear.apply_data(gear_data)
	gear.owner_id = owner_id
	gear.zone = Gear.Zone.HAND
	hand.append(gear)
	add_child(gear)
	EventBus.hand_updated.emit(player_id, hand)
	return gear

# Формирует стартовую руку заданного размера
func draw_starting_hand(hand_size: int) -> void:
	for i in range(hand_size):
		draw_card()

# Удаляет шестерню из руки (без возврата в колоду)
func remove_from_hand(gear: Gear) -> bool:
	if gear in hand:
		hand.erase(gear)
		remove_child(gear)
		EventBus.hand_updated.emit(player_id, hand)
		return true
	return false

# Возвращает шестерню с доски в руку (используется способностью Boomerang)
func return_gear_to_hand(gear: Gear) -> void:
	if gear in hand:
		return
	var parent = gear.get_parent()
	if parent is Cell:
		parent.occupied_gear = null
		if game_manager:
			game_manager.game_state.chain_graph.remove_vertex(parent.board_pos)
			EventBus.chain_built.emit(game_manager.game_state.chain_graph.to_dict())
	if gear.get_parent():
		gear.get_parent().remove_child(gear)
	
	if game_manager and game_manager.game_state:
		game_manager.game_state.effect_system.remove_modifiers_from_target(gear)
	if game_manager:
		game_manager.unregister_gear_effects(gear)
	
	if game_manager and game_manager.event_handler:
		if gear.rotated.is_connected(game_manager.event_handler._on_gear_rotated):
			gear.rotated.disconnect(game_manager.event_handler._on_gear_rotated)
		if gear.destroyed.is_connected(game_manager.event_handler._on_gear_destroyed):
			gear.destroyed.disconnect(game_manager.event_handler._on_gear_destroyed)
		if gear.clicked.is_connected(game_manager.event_handler._on_gear_clicked):
			gear.clicked.disconnect(game_manager.event_handler._on_gear_clicked)
		if gear.mouse_entered.is_connected(game_manager.event_handler._on_gear_mouse_entered):
			gear.mouse_entered.disconnect(game_manager.event_handler._on_gear_mouse_entered)
		if gear.mouse_exited.is_connected(game_manager.event_handler._on_gear_mouse_exited):
			gear.mouse_exited.disconnect(game_manager.event_handler._on_gear_mouse_exited)
	
	gear.current_ticks = 0
	gear.is_face_up = false
	gear.damage_taken = 0
	gear.zone = Gear.Zone.HAND
	if gear.has_method("update_damage_label"):
		gear.update_damage_label()
	if gear.texture_reverse:
		gear.sprite.texture = gear.texture_reverse
	gear.update_rotation()
	
	hand.append(gear)
	add_child(gear)
	EventBus.hand_updated.emit(player_id, hand)
