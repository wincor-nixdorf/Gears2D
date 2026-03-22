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
@onready var pulse_rect: Panel = $PulseRect
@onready var active_pulse_rect: Panel = $ActivePulseRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _active_tween: Tween
var _pulse_tween: Tween

func _ready():
	if not pulse_rect:
		pulse_rect = Panel.new()
		pulse_rect.name = "PulseRect"
		add_child(pulse_rect)
	
	if not active_pulse_rect:
		active_pulse_rect = Panel.new()
		active_pulse_rect.name = "ActivePulseRect"
		add_child(active_pulse_rect)
	
	highlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_pulse_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	input_event.connect(_on_input_event)
	_setup_panel_style(highlight_rect, Color.YELLOW, 2)
	_setup_panel_style(active_rect, Color.RED, 3)
	_setup_pulse_style(pulse_rect, Color(0.3, 0.6, 1.0, 0.4))
	_setup_pulse_style(active_pulse_rect, Color(1.0, 0.5, 0.2, 0.6))
	
	highlight_rect.visible = false
	active_rect.visible = false
	pulse_rect.visible = false
	active_pulse_rect.visible = false
	set_highlight_size(cell_size)

func _setup_panel_style(panel: Panel, border_color: Color, border_width: int):
	if not panel:
		return
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
	new_style.corner_radius_top_left = 8
	new_style.corner_radius_top_right = 8
	new_style.corner_radius_bottom_left = 8
	new_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", new_style)

func _setup_pulse_style(panel: Panel, color: Color):
	if not panel:
		return
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

func set_highlight_size(size: int):
	cell_size = size
	var half_size = Vector2(size / 2.0, size / 2.0)
	
	if highlight_rect:
		highlight_rect.position = -half_size
		highlight_rect.size = Vector2(size, size)
	if active_rect:
		active_rect.position = -half_size
		active_rect.size = Vector2(size, size)
	if pulse_rect:
		pulse_rect.position = -half_size
		pulse_rect.size = Vector2(size, size)
	if active_pulse_rect:
		active_pulse_rect.position = -half_size
		active_pulse_rect.size = Vector2(size, size)
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = Vector2(size, size)

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
	
	if active:
		_start_active_pulse()
	else:
		_stop_active_pulse()

func set_pulsing(pulsing: bool):
	if pulse_rect:
		pulse_rect.visible = pulsing
	if pulsing:
		_start_pulse()
	else:
		_stop_pulse()

func _start_active_pulse() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	
	active_pulse_rect.visible = true
	active_pulse_rect.modulate = Color(1, 1, 1, 1)
	
	_active_tween = create_tween()
	_active_tween.set_loops()
	_active_tween.tween_property(active_pulse_rect, "modulate", Color(1, 1, 1, 0.3), 0.6)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	_active_tween.tween_property(active_pulse_rect, "modulate", Color(1, 1, 1, 1), 0.6)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)

func _stop_active_pulse() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	active_pulse_rect.visible = false

func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	
	pulse_rect.visible = true
	pulse_rect.modulate = Color(1, 1, 1, 0.4)
	
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(pulse_rect, "modulate", Color(1, 1, 1, 0.8), 0.8)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(pulse_rect, "modulate", Color(1, 1, 1, 0.4), 0.8)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)

func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	pulse_rect.visible = false

func is_white() -> bool:
	return Game.is_cell_white(board_pos)

func is_black() -> bool:
	return not is_white()
