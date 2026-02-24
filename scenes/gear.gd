extends Node2D

# Сигналы
signal rotated(gear: Node2D, old_ticks: int, new_ticks: int)
signal triggered(gear: Node2D)
signal destroyed(gear: Node2D)

# Экспортируемые переменные (для настройки в редакторе)
@export var gear_name: String = "Generic Gear"
@export var owner_id: int = 0               # 0 - игрок 1, 1 - игрок 2
@export var max_good_ticks: int = 3         # сколько тиков до срабатывания (скрыто)
@export var max_bad_ticks: int = 2          # сколько тиков до уничтожения (скрыто)

# Текстуры (задаются в инспекторе)
@export var texture_reverse: Texture2D      # реверс (с указателем)
@export var texture_obverse: Texture2D       # аверс (после срабатывания)

# Внутренние переменные
var is_face_up: bool = false
var current_ticks: int = 0                  # 0 - начальное положение
var is_triggered: bool = false

# Ссылки на ноды
@onready var sprite: Sprite2D = $Sprite
@onready var click_area: Area2D = $ClickArea

func _ready():
	# Устанавливаем начальную текстуру (реверс)
	sprite.texture = texture_reverse
	# Поворачиваем спрайт в соответствии с начальным положением (0 тиков)
	update_rotation()
	# Подключаем сигнал входа мыши для подсветки (опционально)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)

# Поворачивает спрайт на угол, соответствующий current_ticks.
# Угол = -current_ticks * 30° (отрицательный угол = поворот по часовой стрелке в Godot).
func update_rotation():
	var angle_deg = -current_ticks * 30.0
	sprite.rotation_degrees = angle_deg     

# Повернуть по часовой стрелке (тик)
func rotate_clockwise(ticks: int = 1) -> bool:
	if is_triggered:
		return false  # сработавшую монету нельзя вращать
	var old_ticks = current_ticks
	current_ticks += ticks
	# Проверяем достижение хорошего конца
	if current_ticks >= max_good_ticks:
		trigger()
		return true
	update_rotation()
	rotated.emit(self, old_ticks, current_ticks)
	return true

# Повернуть против часовой стрелки (так)
func rotate_counterclockwise(ticks: int = 1) -> bool:
	if is_triggered:
		return false
	var old_ticks = current_ticks
	current_ticks -= ticks
	# Проверяем достижение плохого конца
	if current_ticks <= -max_bad_ticks:
		destroy()
		return true
	update_rotation()
	rotated.emit(self, old_ticks, current_ticks)
	return true

# Срабатывание монеты
func trigger():
	if is_triggered:
		return
	is_triggered = true
	is_face_up = true
	sprite.texture = texture_obverse
	# Фиксируем поворот (обычно аверс не вращается)
	sprite.rotation_degrees = 0             
	triggered.emit(self)

# Уничтожение монеты
func destroy():
	destroyed.emit(self)
	queue_free()

# Проверка, может ли монета ещё вращаться
func can_rotate() -> bool:
	return not is_triggered

# Возвращает оставшиеся тики до срабатывания (положительное число)
func ticks_to_trigger() -> int:
	return max(0, max_good_ticks - current_ticks)

# Возвращает оставшиеся тики до уничтожения (положительное число)
func ticks_to_destruction() -> int:
	if current_ticks < 0:
		# Мы уже ушли в отрицательную область
		return max(0, max_bad_ticks + current_ticks)  # current_ticks отрицательное, например -1 => max-1
	else:
		return max_bad_ticks

# Для владельца: показать скрытые параметры (например, при наведении)
func peek() -> Dictionary:
	return {
		"max_good": max_good_ticks,
		"max_bad": max_bad_ticks,
		"current_ticks": current_ticks,
		"is_face_up": is_face_up
	}

# Опционально: подсветка при наведении
func _on_mouse_entered():
	modulate = Color(1, 1, 0.8)  # легкая подсветка

func _on_mouse_exited():
	modulate = Color.WHITE


func _on_click_area_area_entered(area):
	_on_mouse_entered()
