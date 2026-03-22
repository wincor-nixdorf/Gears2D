# gear.gd
class_name Gear
extends Node2D

enum Zone {
	HAND,
	BOARD,
	GRAVE,
	EXILE
}

class AbilitySlot:
	var ability: Ability
	var type: GameEnums.AbilityType
	var cost: int
	var trigger: int  # условие для триггерных, -1 для остальных
	
	func _init(p_ability: Ability, p_type: GameEnums.AbilityType, p_cost: int, p_trigger: int):
		ability = p_ability
		type = p_type
		cost = p_cost
		trigger = p_trigger

signal rotated(gear: Gear, old_ticks: int, new_ticks: int)
signal triggered(gear: Gear)
signal destroyed(gear: Gear)
signal clicked(gear: Gear, button_index: int)
signal mouse_entered(gear: Gear)
signal mouse_exited(gear: Gear)

var gear_name: String = "Generic Gear"
var supertype: GameEnums.GearSupertype = GameEnums.GearSupertype.NONE
var type: GameEnums.GearType = GameEnums.GearType.ROUTINE
var subtype: GameEnums.GearSubtype = GameEnums.GearSubtype.NONE
var speed: int = 0
var is_flying: bool = false
var impact: int = 0
var resistance_base: int = 0          # базовое сопротивление (только для существ)
var owner_id: int = 0
var max_ticks: int = 3
var max_tocks: int = 2
var texture_reverse: Texture2D
var texture_obverse: Texture2D

var zone: Zone = Zone.HAND
var is_face_up: bool = false
var current_ticks: int = 0
var board_position: Vector2i = Vector2i(-1, -1)
var ability_slots: Array[AbilitySlot] = []
var damage_taken: int = 0              # накопленный урон (только для существ)
var revealed: bool = false              # видна ли информация противнику

var game_manager: GameManager

@onready var sprite: Sprite2D = $Sprite
@onready var click_area: Area2D = $ClickArea
@onready var collision_shape: CollisionShape2D = $ClickArea/CollisionShape2D

var _current_tween: Tween

func set_game_manager(gm: GameManager) -> void:
	game_manager = gm

func _ready() -> void:
	click_area.input_event.connect(_on_click_area_input)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	update_texture()

func apply_data(data: GearData) -> void:
	gear_name = data.gear_name
	supertype = data.supertype
	type = data.type
	subtype = data.subtype
	speed = data.speed
	is_flying = data.is_flying
	impact = data.impact
	resistance_base = data.resistance
	max_ticks = data.max_ticks
	max_tocks = data.max_tocks
	texture_reverse = data.texture_reverse
	texture_obverse = data.texture_obverse
	damage_taken = 0
	revealed = false
	
	ability_slots.clear()
	for slot_data in data.ability_slots:
		var ability = game_manager.get_ability_by_id(slot_data.ability_id)
		if ability:
			var slot = AbilitySlot.new(ability, slot_data.type, slot_data.cost, slot_data.trigger)
			ability_slots.append(slot)
	
	update_texture()
	update_rotation()

func update_texture() -> void:
	if not sprite:
		return
	if is_face_up and texture_obverse:
		sprite.texture = texture_obverse
	elif texture_reverse:
		sprite.texture = texture_reverse
	else:
		sprite.texture = null

func set_cell_size(cell_size: float, indent: float = 0.9) -> void:
	if not sprite:
		return
	var target_size = cell_size * indent
	if sprite.texture:
		var tex_size = sprite.texture.get_size()
		sprite.scale = Vector2(target_size / tex_size.x, target_size / tex_size.y)
	else:
		sprite.scale = Vector2(target_size / 100.0, target_size / 100.0)
	if collision_shape:
		if collision_shape.shape == null or not (collision_shape.shape is CircleShape2D):
			var new_shape = CircleShape2D.new()
			collision_shape.shape = new_shape
		collision_shape.shape.radius = target_size / 2.0

func update_rotation() -> void:
	if not sprite:
		return
	sprite.rotation_degrees = current_ticks * 30.0

func _animate_rotation(target_ticks: int) -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	var target_angle = target_ticks * 30.0
	_current_tween = create_tween()
	_current_tween.tween_property(sprite, "rotation_degrees", target_angle, 0.5)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_LINEAR)
	await _current_tween.finished

func get_interrupt_cost() -> int:
	for slot in ability_slots:
		if slot.type == GameEnums.AbilityType.ACTIVATED:
			return slot.cost
	return 1  # стоимость по умолчанию
	
func do_tick(ticks: int = 1) -> bool:
	if is_face_up:
		return false
	var old_ticks = current_ticks
	current_ticks += ticks
	if current_ticks >= max_ticks:
		await _animate_rotation(max_ticks)
		flip()
		rotated.emit(self, old_ticks, current_ticks)
		return true
	await _animate_rotation(current_ticks)
	rotated.emit(self, old_ticks, current_ticks)
	return true

func do_tock(ticks: int = 1) -> bool:
	if is_face_up:
		return false
	var old_ticks = current_ticks
	current_ticks -= ticks
	if current_ticks <= -max_tocks:
		await _animate_rotation(-max_tocks)
		destroy()
		rotated.emit(self, old_ticks, current_ticks)
		return true
	await _animate_rotation(current_ticks)
	rotated.emit(self, old_ticks, current_ticks)
	return true

# Общий метод для добавления всех триггерных способностей в стек (с учётом batch)
func push_triggered_abilities_to_stack() -> void:
	# Проверяем, не предотвращён ли триггер
	if game_manager and game_manager.is_trigger_prevented(self):
		GameLogger.debug("Trigger prevented by Mana Leak for %s" % gear_name)
		return

	var trigger_slots = []
	for slot in ability_slots:
		if slot.type == GameEnums.AbilityType.TRIGGERED and slot.trigger == GameEnums.TriggerCondition.ON_TRIGGER:
			trigger_slots.append(slot)
	
	if trigger_slots.is_empty():
		return
	
	GameLogger.debug("Gear %s: pushing %d triggered abilities to stack" % [gear_name, trigger_slots.size()])
	
	game_manager.stack_manager.begin_batch(owner_id)
	for slot in trigger_slots:
		var context = {"source_gear": self}
		GameLogger.debug("Gear %s: adding ability %s to stack" % [gear_name, slot.ability.ability_name])
		game_manager.stack_manager.push_effect_with_target(slot.ability, self, context)
	game_manager.stack_manager.end_batch()


func flip() -> void:
	if is_face_up:
		return
	is_face_up = true
	revealed = true   # после переворота информация становится видна
	update_texture()
	sprite.rotation_degrees = 0
	_apply_static_effects()
	
	# Добавляем триггерные способности в стек (через batch)
	push_triggered_abilities_to_stack()
	
	# Если это TUNING, добавляем себя в список на возврат после разрешения стека
	if type == GameEnums.GearType.TUNING:
		if game_manager and game_manager.game_state:
			game_manager.game_state.tuning_to_reset.append(self)
	
	triggered.emit(self)

# Вызывается из game_manager после опустошения стека
func reset_tuning() -> void:
	if not is_instance_valid(self):
		return
	if zone != Zone.BOARD:
		return
	if not is_face_up:
		return
	# Возвращаем в исходное положение
	is_face_up = false
	current_ticks = 0
	revealed = true   # остаётся видимой
	update_texture()
	update_rotation()
	GameLogger.debug("Tuning gear %s reset to face-down at %s" % [gear_name, Game.pos_to_chess(board_position)])

func _apply_static_effects() -> void:
	for slot in ability_slots:
		if slot.type == GameEnums.AbilityType.STATIC:
			slot.ability.execute({"source_gear": self})

func trigger() -> void:
	# Для совместимости
	push_triggered_abilities_to_stack()

func destroy() -> void:
	zone = Zone.GRAVE
	var cell = get_parent() as Cell
	if cell:
		cell.occupied_gear = null
	# Удаляем из списка на возврат, если была там
	if game_manager and game_manager.game_state:
		var idx = game_manager.game_state.tuning_to_reset.find(self)
		if idx != -1:
			game_manager.game_state.tuning_to_reset.remove_at(idx)
	# Удаляем все модификаторы
	if game_manager:
		game_manager.game_state.effect_system.remove_modifiers_from_target(self)
		game_manager.game_state.effect_system.remove_modifiers_from_source(self)
	destroyed.emit(self)
	queue_free()

func get_current_resistance() -> int:
	if type != GameEnums.GearType.CREATURE:
		return 0
	var bonus = 0
	if game_manager:
		bonus = game_manager.game_state.effect_system.get_resistance_bonus(self)
	return resistance_base + bonus - damage_taken

func take_damage(amount: int) -> void:
	if type != GameEnums.GearType.CREATURE:
		if not is_face_up:
			do_tock(amount)
		return
	damage_taken += amount
	GameLogger.debug("%s takes %d damage, current resistance: %d" % [gear_name, amount, get_current_resistance()])
	if game_manager:
		game_manager.request_state_based_check()

func can_rotate() -> bool:
	return not is_face_up

func is_owned_by(player: int) -> bool:
	return owner_id == player

func has_ability_id(aid: int) -> bool:
	for slot in ability_slots:
		if slot.ability.ability_id == aid:
			return true
	return false

func get_type_line() -> String:
	var line = ""
	if supertype != GameEnums.GearSupertype.NONE:
		line += GameEnums.GearSupertype.keys()[supertype] + " "
	
	match type:
		GameEnums.GearType.ROUTINE:
			line += "Routine"
		GameEnums.GearType.CREATURE:
			line += "Creature"
		GameEnums.GearType.TUNING:
			line += "Tuning"
		GameEnums.GearType.INTERRUPT:
			line += "Interrupt"
	
	if subtype != GameEnums.GearSubtype.NONE:
		line += " — " + GameEnums.GearSubtype.keys()[subtype]
	return line

func get_abilities_description() -> String:
	if ability_slots.is_empty():
		return "No abilities"
	var desc = ""
	for slot in ability_slots:
		if slot.ability.ability_id == GameEnums.AbilityID.STRIKE:
			continue
		var prefix = ""
		match slot.type:
			GameEnums.AbilityType.TRIGGERED:
				prefix = "Triggered: "
			GameEnums.AbilityType.ACTIVATED:
				# Для Interrupt карт показываем просто "Interrupt X"
				if slot.ability.ability_id == GameEnums.AbilityID.INTERRUPT:
					prefix = "Interrupt %d" % slot.cost
				else:
					prefix = "Activated (%d T): " % slot.cost
			GameEnums.AbilityType.STATIC:
				prefix = "Static: "
		desc += prefix + slot.ability.description + "\n"
	return desc.strip_edges()

func get_tooltip_text() -> String:
	var can_see_full = (owner_id == game_manager.game_state.active_player_id) or revealed
	if not can_see_full:
		var owner_str = "Player 1" if owner_id == 0 else "Player 2"
		return "Unknown Gear (owned by %s)" % owner_str
	
	var owner_str = "Player 1" if owner_id == 0 else "Player 2"
	var type_line = get_type_line()
	var abilities_desc = get_abilities_description()
	
	var type_str = ""
	match type:
		GameEnums.GearType.ROUTINE:
			type_str = "Routine"
		GameEnums.GearType.CREATURE:
			type_str = "Creature"
		GameEnums.GearType.TUNING:
			type_str = "Tuning"
		GameEnums.GearType.INTERRUPT:
			type_str = "Interrupt"
	
	var base = "Gear: %s\nType: %s\n%s\nTocks: %d\nTicks: %d\nOwner: %s" % [
		gear_name, type_str, type_line, max_tocks, max_ticks, owner_str
	]
	
	if not is_face_up:
		base += "\nTime: %d" % current_ticks
	
	if type == GameEnums.GearType.CREATURE:
		base += "\nSpeed: %d" % speed
		if is_flying:
			base += "\nFlying"
		var current_res = get_current_resistance()
		base += "\nImpact: %d\nResistance: %d (%d base, %d damage)" % [impact, current_res, resistance_base, damage_taken]
		var bonus = 0
		if game_manager:
			bonus = game_manager.game_state.effect_system.get_resistance_bonus(self)
		if bonus != 0:
			base += " +%d bonus" % bonus
	
	if abilities_desc:
		base += "\n\n%s" % abilities_desc
	
	return base

func show_obverse_temporarily() -> void:
	if not texture_obverse:
		return
	var original_texture = sprite.texture
	var original_rotation = sprite.rotation_degrees
	sprite.texture = texture_obverse
	sprite.rotation_degrees = 0
	await get_tree().create_timer(2.0).timeout
	if not is_face_up:
		sprite.texture = original_texture
		sprite.rotation_degrees = original_rotation
	revealed = true

func _on_click_area_input(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		clicked.emit(self, event.button_index)
		viewport.set_input_as_handled()

func _on_mouse_entered() -> void:
	if GameManager.ref and GameManager.ref.ui and GameManager.ref.ui.is_target_selection_active():
		return
	modulate = Color(1, 1, 0.8)
	mouse_entered.emit(self)

func _on_mouse_exited() -> void:
	if GameManager.ref and GameManager.ref.ui and GameManager.ref.ui.is_target_selection_active():
		return
	modulate = Color.WHITE
	mouse_exited.emit(self)

func is_on_board() -> bool:
	return zone == Zone.BOARD

func set_selected(selected: bool) -> void:
	if selected:
		modulate = Color.YELLOW
	else:
		modulate = Color.WHITE
