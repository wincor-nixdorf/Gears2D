# gear.gd
class_name Gear
extends Node2D

# Перечисление зон
enum Zone {
	HAND,   # в руке
	BOARD,  # на доске
	GRAVE,  # в сбросе (уничтожена)
	EXILE   # изгнана (безвозвратно)
}

# Сигналы
signal rotated(gear: Gear, old_ticks: int, new_ticks: int)
signal triggered(gear: Gear)
signal destroyed(gear: Gear)
signal clicked(gear: Gear, button_index: int)
signal mouse_entered(gear: Gear)
signal mouse_exited(gear: Gear)

# Параметры шестерни
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

# Состояние
var zone: Zone = Zone.HAND
var is_face_up: bool = false
var current_ticks: int = 0
var is_triggered: bool = false
var board_position: Vector2i = Vector2i(-1, -1)
var abilities: Array[Ability] = []
var damage_taken: int = 0

var game_manager: GameManager

@onready var sprite: Sprite2D = $Sprite
@onready var click_area: Area2D = $ClickArea
@onready var collision_shape: CollisionShape2D = $ClickArea/CollisionShape2D

var _current_tween: Tween

func set_game_manager(gm: GameManager) -> void:
	game_manager = gm

func _ready() -> void:
	if texture_reverse:
		sprite.texture = texture_reverse
	else:
		push_error("Gear: texture_reverse not assigned!")
	update_rotation()
	click_area.input_event.connect(_on_click_area_input)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)

# Заполняет данные из GearData
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
	abilities = data.abilities.duplicate()
	damage_taken = 0
	if sprite:
		if texture_reverse:
			sprite.texture = texture_reverse
		update_rotation()

# Устанавливает размер спрайта в соответствии с размером клетки
func set_cell_size(cell_size: float, indent: float = 0.9) -> void:
	var spr = $Sprite
	if not spr:
		return
	var target_size = cell_size * indent
	if spr.texture:
		var tex_size = spr.texture.get_size()
		spr.scale = Vector2(target_size / tex_size.x, target_size / tex_size.y)
	else:
		spr.scale = Vector2(target_size / 100.0, target_size / 100.0)
	if collision_shape:
		if collision_shape.shape == null or not (collision_shape.shape is CircleShape2D):
			var new_shape = CircleShape2D.new()
			collision_shape.shape = new_shape
		collision_shape.shape.radius = target_size / 2.0

# Обновляет вращение спрайта в соответствии с current_ticks
func update_rotation() -> void:
	if not sprite:
		return
	sprite.rotation_degrees = current_ticks * 30.0

# Анимирует поворот к заданному количеству тиков
func _animate_rotation(target_ticks: int) -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	var target_angle = target_ticks * 30.0
	_current_tween = create_tween()
	_current_tween.tween_property(sprite, "rotation_degrees", target_angle, 0.5)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_LINEAR)
	
	await _current_tween.finished

# Выполняет поворот на указанное количество тиков вперёд
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

# Выполняет поворот на указанное количество тиков назад (так)
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

# Переворот шестерни (лицевой стороной вверх)
func flip() -> void:
	if is_face_up:
		return
	is_face_up = true
	if texture_obverse:
		sprite.texture = texture_obverse
	sprite.rotation_degrees = 0
	
	# 1. Немедленное выполнение статических способностей
	_apply_static_effects()
	
	# 2. Если есть триггерные способности, добавляем их в стек
	if _has_trigger_abilities() and not is_triggered:
		trigger()
	
	triggered.emit(self)

# Применяет все статические способности шестерни
func _apply_static_effects() -> void:
	for ability in abilities:
		if ability.ability_type == GameEnums.AbilityType.STATIC:
			ability.execute({"source_gear": self})

# Проверяет наличие триггерных способностей
func _has_trigger_abilities() -> bool:
	for ability in abilities:
		if ability.ability_type == GameEnums.AbilityType.TRIGGERED:
			return true
	return false

# Добавляет триггерные способности в стек
func trigger() -> void:
	if is_triggered:
		return
	is_triggered = true
	
	for ability in abilities:
		if ability.ability_type == GameEnums.AbilityType.TRIGGERED:
			var context = {"source_gear": self}
			GameLogger.debug("Gear %s: adding ability %s to stack" % [gear_name, ability.ability_name])
			game_manager.stack_manager.push_effect(ability, self, null, context)

# Уничтожает шестерню
func destroy() -> void:
	zone = Zone.GRAVE
	var cell = get_parent() as Cell
	if cell:
		cell.occupied_gear = null
	destroyed.emit(self)
	queue_free()

# Наносит урон шестерне
func take_damage(amount: int) -> void:
	damage_taken += amount
	var total_groove = max_ticks + max_tocks
	if damage_taken >= total_groove:
		destroy()

# Проверяет, может ли шестерня вращаться (не перевёрнута)
func can_rotate() -> bool:
	return not is_face_up

# Проверяет, принадлежит ли шестерня указанному игроку
func is_owned_by(player: int) -> bool:
	return owner_id == player

# Проверяет наличие способности с заданным ID
func has_ability_id(aid: int) -> bool:
	for a in abilities:
		if a.ability_id == aid:
			return true
	return false

# Возвращает строку типа (например, "Legendary Creature — Gearling")
func get_type_line() -> String:
	var line = ""
	if supertype != GameEnums.GearSupertype.NONE:
		line += GameEnums.GearSupertype.keys()[supertype] + " "
	line += GameEnums.GearType.keys()[type]
	if subtype != GameEnums.GearSubtype.NONE:
		line += " — " + GameEnums.GearSubtype.keys()[subtype]
	return line

# Возвращает строку с описанием способностей
func get_abilities_description() -> String:
	if abilities.is_empty():
		return "No abilities"
	var desc = ""
	for ability in abilities:
		desc += ability.description + "\n"
	return desc.strip_edges()

# Возвращает текст для подсказки
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

# Показывает аверс на короткое время (для фазы upturn)
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
	if game_manager and game_manager.ui.is_target_selection_active():
		return
	modulate = Color(1, 1, 0.8)
	mouse_entered.emit(self)

func _on_mouse_exited() -> void:
	if game_manager and game_manager.ui.is_target_selection_active():
		return
	modulate = Color.WHITE
	mouse_exited.emit(self)

# Проверяет, находится ли шестерня на доске
func is_on_board() -> bool:
	return zone == Zone.BOARD

# Визуальное выделение существа
func set_selected(selected: bool) -> void:
	if selected:
		modulate = Color.YELLOW
	else:
		modulate = Color.WHITE
