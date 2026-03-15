# stack_panel.gd
extends Panel

@onready var container: VBoxContainer = $VBoxContainer
@onready var resolve_button: Button = %ResolveButton

var _stack_manager: StackManager
var _entry_scene = preload("res://scenes/stack_entry.tscn")

func _ready():
	if resolve_button:
		resolve_button.pressed.connect(_on_resolve_pressed)
		print("Resolve button connected")
	else:
		push_error("resolve_button not found")
	
	EventBus.target_selection_started.connect(_on_target_selection_started)
	EventBus.target_selection_cancelled.connect(_on_target_selection_ended)
	EventBus.target_selected.connect(_on_target_selection_ended)
	
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_stack_manager(sm: StackManager):
	_stack_manager = sm
	EventBus.stack_updated.connect(_on_stack_updated)

func _on_stack_updated(snapshot: Array):
	print("Stack updated, snapshot size: ", snapshot.size())
	for child in container.get_children():
		child.queue_free()
	
	for entry_data in snapshot:
		print("Creating entry for: ", entry_data.ability_name, " id=", entry_data.id)
		var entry_ui = _entry_scene.instantiate()
		container.add_child(entry_ui)
		entry_ui.setup(entry_data, _stack_manager)
	
	visible = not snapshot.is_empty()

func _on_resolve_pressed():
	print("Resolve button pressed")
	_stack_manager.resolve_next()

func _on_cancel_pressed():
	_stack_manager.clear_stack()
	hide()

func _on_target_selection_started():
	resolve_button.disabled = true

func _on_target_selection_ended(_arg = null):
	resolve_button.disabled = false
