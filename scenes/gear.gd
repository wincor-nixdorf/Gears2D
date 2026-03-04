# gear.gd
class_name Gear
extends Node2D

signal rotated(gear: Node2D, old_ticks: int, new_ticks: int)
signal triggered(gear: Node2D)
signal destroyed(gear: Node2D)
signal clicked(gear: Node2D)
signal mouse_entered(gear: Node2D)
signal mouse_exited(gear: Node2D)

@export var gear_name: String = "Generic Gear"
@export var owner_id: int = 0
@export var max_ticks: int = 3        # количество тиков до срабатывания
@export var max_tocks: int = 2        # количество таков до уничтожения
@export var texture_reverse: Texture2D
@export var texture_obverse: Texture2D

var is_face_up: bool = false
var current_ticks: int = 0
var is_triggered: bool = false
var board_position: Vector2i = Vector2i(-1, -1)

@onready var sprite: Sprite2D = $Sprite
@onready var click_area: Area2D = $ClickArea
@onready var collision_shape: CollisionShape2D = $ClickArea/CollisionShape2D

func _ready():
	if not sprite:
		push_error("Gear: Sprite node not found! Check the scene structure.")
		return
	if texture_reverse:
		sprite.texture = texture_reverse
	else:
		push_error("Gear: texture_reverse not assigned!")
	
	update_rotation()
	click_area.input_event.connect(_on_click_area_input)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)

func set_cell_size(cell_size: float, indent: float = 0.9):
	var spr = get_node_or_null("Sprite")
	if not spr:
		push_error("Gear.set_cell_size: Sprite node not found!")
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

func update_rotation():
	if not sprite:
		return
	var angle_deg = current_ticks * 30.0
	sprite.rotation_degrees = angle_deg

# Прежний rotate_clockwise теперь называется do_tick
func do_tick(ticks: int = 1) -> bool:
	if is_triggered:
		return false
	var old_ticks = current_ticks
	current_ticks += ticks
	if current_ticks >= max_ticks:
		trigger()
		return true
	update_rotation()
	rotated.emit(self, old_ticks, current_ticks)
	return true

# Прежний rotate_counterclockwise теперь называется do_tock
func do_tock(ticks: int = 1) -> bool:
	if is_triggered:
		return false
	var old_ticks = current_ticks
	current_ticks -= ticks
	if current_ticks <= -max_tocks:
		destroy()
		return true
	update_rotation()
	rotated.emit(self, old_ticks, current_ticks)
	return true

func trigger():
	if is_triggered:
		return
	is_triggered = true
	is_face_up = true
	if texture_obverse:
		sprite.texture = texture_obverse
	else:
		push_error("Gear: texture_obverse not assigned!")
	sprite.rotation_degrees = 0
	triggered.emit(self)

func destroy():
	destroyed.emit(self)
	queue_free()

func can_rotate() -> bool:
	return not is_triggered

func ticks_to_trigger() -> int:
	return max(0, max_ticks - current_ticks)

# Переименовано: ticks_to_destruction -> tocks_to_destruction
func tocks_to_destruction() -> int:
	if current_ticks < 0:
		return max(0, max_tocks + current_ticks)
	else:
		return max_tocks

func can_take_ticks(ticks: int) -> int:
	var available = max_tocks + current_ticks
	return min(ticks, max(0, available))

func peek() -> Dictionary:
	return {
		"max_ticks": max_ticks,
		"max_tocks": max_tocks,
		"current_ticks": current_ticks,
		"is_face_up": is_face_up
	}

func get_max_tocks() -> int:
	return max(0, max_tocks + current_ticks)

func get_max_ticks() -> int:
	return max(0, max_ticks - current_ticks)

# Новый метод для проверки владельца
func is_owned_by(player: int) -> bool:
	return owner_id == player

func _on_click_area_input(viewport: Node, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)
		viewport.set_input_as_handled()  # Помечаем событие как обработанное

func _on_mouse_entered():
	print("Gear mouse entered, owner=", owner_id)
	modulate = Color(1, 1, 0.8)
	mouse_entered.emit(self)

func _on_mouse_exited():
	print("Gear mouse exited, owner=", owner_id)
	modulate = Color.WHITE
	mouse_exited.emit(self)

func randomize_params():
	max_ticks = randi() % 6 + 1
	max_tocks = randi() % 6 + 1
	gear_name = "Gear"

func get_tooltip_text() -> String:
	var owner_str = "Player 1" if owner_id == 0 else "Player 2"
	return "Gear: %s\nTocks: %d\nTicks: %d\nTime: %d\nOwner: %s" % [
		gear_name,
		max_tocks,
		max_ticks,
		current_ticks,
		owner_str
	]

func show_obverse_temporarily():
	if not texture_obverse:
		push_error("Gear: texture_obverse not assigned!")
		return
	var original_texture = sprite.texture
	var original_rotation = sprite.rotation_degrees
	sprite.texture = texture_obverse
	sprite.rotation_degrees = 0
	await get_tree().create_timer(2.0).timeout
	if not is_face_up:
		sprite.texture = original_texture
		sprite.rotation_degrees = original_rotation

func apply_effect():
	pass
