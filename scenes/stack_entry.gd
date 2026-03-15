# stack_entry.gd
extends HBoxContainer

@onready var icon: TextureRect = $Icon
@onready var label: Label = $Label
@onready var up_button: Button = $UpButton
@onready var down_button: Button = $DownButton

var _entry_id: int
var _stack_manager: StackManager

func setup(entry_data: Dictionary, stack_manager: StackManager):
	_entry_id = entry_data.id
	_stack_manager = stack_manager
	
	if icon:
		# Здесь можно установить иконку игрока или способности
		pass
	else:
		push_error("Icon node not found")
	
	if label:
		var owner_text = "P1" if entry_data.source_owner_id == 0 else "P2"
		var pos = Vector2i(entry_data.source_pos_x, entry_data.source_pos_y)
		var pos_text = Game.pos_to_chess(pos)
		# Изменено: название способности в скобках
		label.text = "(%s) from %s at %s (%s)" % [entry_data.ability_name, entry_data.source_gear_name, pos_text, owner_text]
	else:
		push_error("Label node not found")
	
	if up_button:
		up_button.pressed.connect(_on_up_pressed)
	else:
		push_error("UpButton not found")
	
	if down_button:
		down_button.pressed.connect(_on_down_pressed)
	else:
		push_error("DownButton not found")

func _on_up_pressed():
	var snapshot = _stack_manager.get_stack_snapshot()
	var index = -1
	for i in range(snapshot.size()):
		if snapshot[i].id == _entry_id:
			index = i
			break
	if index > 0:
		var temp = snapshot[index]
		snapshot[index] = snapshot[index-1]
		snapshot[index-1] = temp
		_stack_manager.set_stack_order(snapshot)

func _on_down_pressed():
	var snapshot = _stack_manager.get_stack_snapshot()
	var index = -1
	for i in range(snapshot.size()):
		if snapshot[i].id == _entry_id:
			index = i
			break
	if index < snapshot.size() - 1:
		var temp = snapshot[index]
		snapshot[index] = snapshot[index+1]
		snapshot[index+1] = temp
		_stack_manager.set_stack_order(snapshot)
