# gear.gd
class_name Gear
extends Node2D

signal rotated(gear: Gear, old_ticks: int, new_ticks: int)
signal triggered(gear: Gear)
signal destroyed(gear: Gear)
signal clicked(gear: Gear)
signal mouse_entered(gear: Gear)
signal mouse_exited(gear: Gear)

var gear_name: String = "Generic Gear"
var owner_id: int = 0
var max_ticks: int = 3
var max_tocks: int = 2
var texture_reverse: Texture2D
var texture_obverse: Texture2D

var is_face_up: bool = false
var current_ticks: int = 0
var is_triggered: bool = false
var board_position: Vector2i = Vector2i(-1, -1)
var abilities: Array[Ability] = []

@onready var sprite: Sprite2D = $Sprite
@onready var click_area: Area2D = $ClickArea
@onready var collision_shape: CollisionShape2D = $ClickArea/CollisionShape2D

func _ready():
	if texture_reverse:
		sprite.texture = texture_reverse
	else:
		push_error("Gear: texture_reverse not assigned!")
	update_rotation()
	click_area.input_event.connect(_on_click_area_input)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)

func apply_data(data: GearData):
	gear_name = data.gear_name
	max_ticks = data.max_ticks
	max_tocks = data.max_tocks
	texture_reverse = data.texture_reverse
	texture_obverse = data.texture_obverse
	abilities = data.abilities.duplicate()
	if sprite:
		if texture_reverse:
			sprite.texture = texture_reverse
		update_rotation()

func set_cell_size(cell_size: float, indent: float = 0.9):
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

func update_rotation():
	if not sprite:
		return
	var angle_deg = current_ticks * 30.0
	sprite.rotation_degrees = angle_deg

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
	GameManager.ref.emit_event(GameEnums.TriggerCondition.ON_TRIGGER, {"gear": self})

func destroy():
	destroyed.emit(self)
	GameManager.ref.emit_event(GameEnums.TriggerCondition.ON_DESTROYED, {"gear": self})
	queue_free()

func can_rotate() -> bool:
	return not is_triggered

func is_owned_by(player: int) -> bool:
	return owner_id == player

func get_abilities_description() -> String:
	if abilities.is_empty():
		return "No abilities"
	var desc = ""
	for ability in abilities:
		#desc += ability.ability_name + ": " + ability.description + "\n"
		desc += ability.description + "\n"
	return desc.strip_edges()

func get_tooltip_text() -> String:
	var owner_str = "Player 1" if owner_id == 0 else "Player 2"
	var abilities_desc = get_abilities_description()
	return "Gear: %s\nTocks: %d\nTicks: %d\nTime: %d\nOwner: %s\n\n%s" % [
		gear_name,
		max_tocks,
		max_ticks,
		current_ticks,
		owner_str,
		abilities_desc
	]

func show_obverse_temporarily():
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

# Сигналы ввода
func _on_click_area_input(viewport: Node, event: InputEvent, shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("Gear click area input: ", gear_name, " at ", board_position)
		clicked.emit(self)
		viewport.set_input_as_handled()

func _on_mouse_entered():
	modulate = Color(1, 1, 0.8)
	mouse_entered.emit(self)

func _on_mouse_exited():
	modulate = Color.WHITE
	mouse_exited.emit(self)
