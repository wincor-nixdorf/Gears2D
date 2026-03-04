# cell.gd
class_name Cell
extends Area2D

## Сигнал испускается при клике левой кнопкой мыши по клетке.
## Передаёт только саму клетку, её позицию можно получить через cell.board_pos.
signal clicked(cell: Cell)

var board_pos: Vector2i          ## Координаты клетки на доске (0..7)
var occupied_gear: Node2D = null ## Шестерёнка, стоящая на клетке (если есть)
var cell_size: int = Game.CELL_SIZE

@onready var sprite: Sprite2D = $Sprite
@onready var highlight_rect: ColorRect = $HighlightRect

func _ready():
	input_event.connect(_on_input_event)
	if highlight_rect:
		highlight_rect.visible = false

## Устанавливает размер области подсветки (должен совпадать с размером клетки).
func set_highlight_size(size: int):
	cell_size = size
	if highlight_rect:
		highlight_rect.position = -Vector2(cell_size/2, cell_size/2)
		highlight_rect.size = Vector2(cell_size, cell_size)

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Клик по клетке ", board_pos)
		clicked.emit(self)   # emit только клетку

## Проверяет, пуста ли клетка (нет шестерёнки).
func is_empty() -> bool:
	return occupied_gear == null

## Устанавливает шестерёнку на клетку.
func set_occupied(gear: Node2D):
	occupied_gear = gear
	add_child(gear)
	gear.position = Vector2.ZERO

## Удаляет шестерёнку с клетки (если есть).
func remove_gear():
	if occupied_gear:
		occupied_gear.queue_free()
		occupied_gear = null

## Включает/выключает подсветку клетки.
func set_highlighted(highlighted: bool):
	if highlight_rect:
		highlight_rect.visible = highlighted

## Возвращает true, если клетка белая (по шахматной раскраске).
func is_white() -> bool:
	return Game.is_cell_white(board_pos)

## Возвращает true, если клетка чёрная.
func is_black() -> bool:
	return not is_white()
