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
var damage_taken: int = 0

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
	max_ticks = data.max_ticks
	max_tocks = data.max_tocks
	texture_reverse = data.texture_reverse
	texture_obverse = data.texture_obverse
	damage_taken = 0
	
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

func flip() -> void:
	if is_face_up:
		return
	is_face_up = true
	update_texture()
	sprite.rotation_degrees = 0
	_apply_static_effects()
	if _has_trigger_abilities():
		trigger()
	triggered.emit(self)

func _apply_static_effects() -> void:
	for slot in ability_slots:
		if slot.type == GameEnums.AbilityType.STATIC:
			slot.ability.execute({"source_gear": self})

func _has_trigger_abilities() -> bool:
	for slot in ability_slots:
		if slot.type == GameEnums.AbilityType.TRIGGERED and slot.trigger == GameEnums.TriggerCondition.ON_TRIGGER:
			return true
	return false

func trigger() -> void:
	for slot in ability_slots:
		if slot.type == GameEnums.AbilityType.TRIGGERED and slot.trigger == GameEnums.TriggerCondition.ON_TRIGGER:
			var context = {"source_gear": self}
			GameLogger.debug("Gear %s: adding ability %s to stack" % [gear_name, slot.ability.ability_name])
			game_manager.stack_manager.push_effect(slot.ability, self, null, context)

func destroy() -> void:
	zone = Zone.GRAVE
	var cell = get_parent() as Cell
	if cell:
		cell.occupied_gear = null
	destroyed.emit(self)
	queue_free()

func take_damage(amount: int) -> void:
	if is_face_up:
		damage_taken += amount
		if damage_taken >= max_ticks + max_tocks:
			destroy()
	else:
		do_tock(amount)

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
	line += GameEnums.GearType.keys()[type]
	if subtype != GameEnums.GearSubtype.NONE:
		line += " — " + GameEnums.GearSubtype.keys()[subtype]
	return line

func get_abilities_description() -> String:
	if ability_slots.is_empty():
		return "No abilities"
	var desc = ""
	for slot in ability_slots:
		var prefix = ""
		match slot.type:
			GameEnums.AbilityType.TRIGGERED:
				prefix = "Triggered: "
			GameEnums.AbilityType.ACTIVATED:
				prefix = "Activated (%d T): " % slot.cost
			GameEnums.AbilityType.STATIC:
				prefix = "Static: "
		desc += prefix + slot.ability.description + "\n"
	return desc.strip_edges()

func get_tooltip_text() -> String:
	var owner_str = "Player 1" if owner_id == 0 else "Player 2"
	var type_line = get_type_line()
	var abilities_desc = get_abilities_description()
	var base = "Gear: %s\n%s\nTocks: %d\nTicks: %d\nTime: %d\nOwner: %s" % [
		gear_name, type_line, max_tocks, max_ticks, current_ticks, owner_str
	]
	if type == GameEnums.GearType.CREATURE:
		base += "\nSpeed: %d" % speed
		if is_flying:
			base += "\nFlying"
	if damage_taken > 0:
		base += "\nDamage: %d/%d" % [damage_taken, max_ticks + max_tocks]
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
