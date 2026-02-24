extends Node2D

# Сигналы
signal rotated(gear: Node2D, old_ticks: int, new_ticks: int)
signal triggered(gear: Node2D)
signal destroyed(gear: Node2D)
signal clicked(gear: Node2D)

# Экспортируемые переменные
@export var gear_name: String = "Generic Gear"
@export var owner_id: int = 0
@export var max_good_ticks: int = 3
@export var max_bad_ticks: int = 2
@export var texture_reverse: Texture2D
@export var texture_obverse: Texture2D

# Внутренние переменные
var is_face_up: bool = false
var current_ticks: int = 0
var is_triggered: bool = false
var board_position: Vector2i = Vector2i(-1, -1)  # будет установлено клеткой

@onready var sprite: Sprite2D = $Sprite
@onready var click_area: Area2D = $ClickArea
@onready var collision_shape: CollisionShape2D = $ClickArea/CollisionShape2D

func _ready():
	sprite.texture = texture_reverse
	update_rotation()
	click_area.input_event.connect(_on_click_area_input)
	# Можно добавить подсветку при наведении
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)

# Новый метод: настраивает спрайт и коллизию под размер клетки
func set_cell_size(cell_size: float, indent: float = 0.9):
	var sprite_node = $Sprite as Sprite2D
	if not sprite_node:
		push_error("Sprite node not found")
		return
	
	var collision_shape_node = $ClickArea/CollisionShape2D as CollisionShape2D
	if not collision_shape_node:
		push_error("CollisionShape2D not found")
		return
	
	var target_size = cell_size * indent
	
	if sprite_node.texture:
		var tex_size = sprite_node.texture.get_size()
		sprite_node.scale = Vector2(target_size / tex_size.x, target_size / tex_size.y)
	else:
		sprite_node.scale = Vector2.ONE
	
	# Устанавливаем коллизию
	if collision_shape_node.shape == null or not (collision_shape_node.shape is CircleShape2D):
		var new_shape = CircleShape2D.new()
		collision_shape_node.shape = new_shape
	collision_shape_node.shape.radius = target_size / 2.0

# Метод для задания радиуса коллизии (круг)
func set_collision_radius(radius: float):
	if collision_shape.shape == null or not (collision_shape.shape is CircleShape2D):
		var new_shape = CircleShape2D.new()
		collision_shape.shape = new_shape
	collision_shape.shape.radius = radius

func update_rotation():
	var angle_deg = -current_ticks * 30.0
	sprite.rotation_degrees = angle_deg

func rotate_clockwise(ticks: int = 1) -> bool:
	if is_triggered:
		return false
	var old_ticks = current_ticks
	current_ticks += ticks
	if current_ticks >= max_good_ticks:
		trigger()
		return true
	update_rotation()
	rotated.emit(self, old_ticks, current_ticks)
	return true

func rotate_counterclockwise(ticks: int = 1) -> bool:
	if is_triggered:
		return false
	var old_ticks = current_ticks
	current_ticks -= ticks
	if current_ticks <= -max_bad_ticks:
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
	sprite.texture = texture_obverse
	sprite.rotation_degrees = 0
	triggered.emit(self)

func destroy():
	destroyed.emit(self)
	queue_free()

func can_rotate() -> bool:
	return not is_triggered

func ticks_to_trigger() -> int:
	return max(0, max_good_ticks - current_ticks)

func ticks_to_destruction() -> int:
	if current_ticks < 0:
		return max(0, max_bad_ticks + current_ticks)
	else:
		return max_bad_ticks

func can_take_ticks(ticks: int) -> int:
	var available = max_bad_ticks + current_ticks
	return min(ticks, max(0, available))

func peek() -> Dictionary:
	return {
		"max_good": max_good_ticks,
		"max_bad": max_bad_ticks,
		"current_ticks": current_ticks,
		"is_face_up": is_face_up
	}

# Обработка клика по шестерне
func _on_click_area_input(viewport: Node, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)

func _on_mouse_entered():
	modulate = Color(1, 1, 0.8)

func _on_mouse_exited():
	modulate = Color.WHITE
