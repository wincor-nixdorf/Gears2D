# player.gd
class_name Player
extends Node

@export var player_id: int = 0
@export var owner_id: int = 0
@export var damage: int = 0

var deck: Array[GearData] = []          # колода из данных (GearData)
var hand: Array[Gear] = []              # рука из экземпляров Gear

const GEAR_SCENE = preload("res://scenes/Gear.tscn")

func _init(pid: int = 0, deck_data: Array[GearData] = []):
	player_id = pid
	owner_id = pid
	deck = deck_data.duplicate()
	hand = []
	deck.shuffle()

func draw_card() -> Gear:
	if deck.is_empty():
		return null
	var gear_data = deck.pop_front()
	var gear = GEAR_SCENE.instantiate()
	gear.apply_data(gear_data)
	gear.owner_id = owner_id
	hand.append(gear)
	add_child(gear)          # делаем Gear дочерним узлом игрока (для удобства)
	return gear

func draw_starting_hand(hand_size: int):
	for i in range(hand_size):
		draw_card()

func remove_from_hand(gear: Gear) -> bool:
	if gear in hand:
		hand.erase(gear)
		remove_child(gear)   # убираем из иерархии игрока
		return true
	return false

func return_gear_to_hand(gear: Gear):
	if gear in hand:
		return
	var parent = gear.get_parent()
	if parent is Cell:
		parent.occupied_gear = null
	if gear.get_parent():
		gear.get_parent().remove_child(gear)
	
	# Удаляем все модификаторы, наложенные на эту шестерню
	GameState.effect_system.remove_modifiers_from_target(gear)
	# Удаляем модификаторы, источником которых является эта шестерня
	GameManager.ref.unregister_gear_effects(gear)
	
	# Сброс состояния
	gear.current_ticks = 0
	gear.is_triggered = false
	gear.is_face_up = false
	if gear.texture_reverse:
		gear.sprite.texture = gear.texture_reverse
	gear.update_rotation()
	
	# Отключаем сигналы
	gear._disconnect_signals()
	
	hand.append(gear)
	add_child(gear)
