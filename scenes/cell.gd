# cell.gd
class_name Cell
extends Area2D

signal clicked(cell: Cell)

var board_pos: Vector2i
var occupied_gear: Node2D = null
var cell_size: int = Game.CELL_SIZE

@onready var sprite: Sprite2D = $Sprite
@onready var highlight_rect: Panel = $HighlightRect
@onready var active_rect: Panel = $ActiveRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	input_event.connect(_on_input_event)
	_setup_panel_style(highlight_rect, Color.YELLOW, 2)
	_setup_panel_style(active_rect, Color.RED, 3)
	highlight_rect.visible = false
	active_rect.visible = false

func _setup_panel_style(panel: Panel, border_color: Color, border_width: int):
	var current_style = panel.get_theme_stylebox("panel")
	var new_style: StyleBoxFlat
	if current_style is StyleBoxFlat:
		new_style = current_style.duplicate()
	else:
		new_style = StyleBoxFlat.new()
	new_style.bg_color = Color.TRANSPARENT
	new_style.border_color = border_color
	new_style.border_width_left = border_width
	new_style.border_width_right = border_width
	new_style.border_width_top = border_width
	new_style.border_width_bottom = border_width
	panel.add_theme_stylebox_override("panel", new_style)

func set_highlight_size(size: int):
	cell_size = size
	if highlight_rect:
		highlight_rect.position = -Vector2(cell_size/2, cell_size/2)
		highlight_rect.size = Vector2(cell_size, cell_size)
	if active_rect:
		active_rect.position = -Vector2(cell_size/2, cell_size/2)
		active_rect.size = Vector2(cell_size, cell_size)
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = Vector2(cell_size, cell_size)

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Клик по клетке ", board_pos)
		clicked.emit(self)
		viewport.set_input_as_handled()

func is_empty() -> bool:
	return occupied_gear == null

func set_occupied(gear: Node2D):
	occupied_gear = gear
	add_child(gear)
	gear.position = Vector2.ZERO

func remove_gear():
	if occupied_gear:
		occupied_gear.queue_free()
		occupied_gear = null

func set_highlighted(highlighted: bool):
	if highlight_rect:
		highlight_rect.visible = highlighted

func set_active(active: bool):
	if active_rect:
		active_rect.visible = active

func is_white() -> bool:
	return Game.is_cell_white(board_pos)

func is_black() -> bool:
	return not is_white()
