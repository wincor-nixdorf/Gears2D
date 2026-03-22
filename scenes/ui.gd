# ui.gd
class_name UI
extends CanvasLayer

signal action_pressed
signal hand_gear_selected(gear: Node2D)
signal interrupt_played(gear: Gear, cell: Cell)

@onready var stack_panel = %StackPanel
@onready var player_label: Label = %PlayerLabel
@onready var phase_label: Label = %PhaseLabel
@onready var t0_label: Label = %T0Label
@onready var t1_label: Label = %T1Label
@onready var action_button: Button = %ActionButton
@onready var hand_container_player1: HBoxContainer = %HandContainerPlayer1
@onready var hand_container_player2: HBoxContainer = %HandContainerPlayer2
@onready var tooltip_panel: Panel = %TooltipPanel
@onready var tooltip_label: Label = %TooltipLabel
@onready var round_label: Label = %RoundLabel
@onready var chain_length_label: Label = %ChainLengthLabel
@onready var prompt_label: Label = %PromptLabel
@onready var damage0_label: Label = %DamagePlayer0Label
@onready var damage1_label: Label = %DamagePlayer1Label
@onready var player0_button: Button = %Player0Button
@onready var player1_button: Button = %Player1Button
@onready var log_panel: Panel = %LogPanel
@onready var log_text: RichTextLabel = %LogText
@onready var filter_debug: CheckBox = %FilterDebug
@onready var filter_info: CheckBox = %FilterInfo
@onready var filter_warning: CheckBox = %FilterWarning
@onready var filter_error: CheckBox = %FilterError
@onready var clear_log_button: Button = %ClearLogButton
@onready var tooltip_icon: TextureRect = %TooltipIcon

var turn_history_panel: TurnHistoryPanel
var _target_selection_active: bool = false
var _current_possible_targets: Array = []
var _original_colors: Dictionary = {}
var _active_player_id: int = 0
var game_manager: GameManager

var _batch_dialog: Window = null
var _batch_entries: Array = []
var _batch_player_id: int
var _batch_ordered: Array = []
var _batch_confirm_button: Button = null

func set_game_manager(gm: GameManager) -> void:
	game_manager = gm

func _ready() -> void:
	action_button.pressed.connect(_on_action_button_pressed)
	tooltip_panel.hide()
	
	GameLogger.message_logged.connect(_on_log_message)
	clear_log_button.pressed.connect(_on_clear_log)
	filter_debug.button_pressed = true
	filter_info.button_pressed = true
	filter_warning.button_pressed = true
	filter_error.button_pressed = true
	
	EventBus.target_selection_requested.connect(_on_target_selection_requested)
	EventBus.target_selection_cancelled.connect(_on_target_selection_cancelled)
	EventBus.batch_ordering_requested.connect(_on_batch_ordering_requested)
	
	player0_button.pressed.connect(_on_player_button_pressed.bind(0))
	player1_button.pressed.connect(_on_player_button_pressed.bind(1))
	
	stack_panel.hide()
	EventBus.stack_updated.connect(_on_stack_updated)
	
	_create_history_panel()

func _create_history_panel() -> void:
	turn_history_panel = TurnHistoryPanel.new()
	turn_history_panel.name = "TurnHistoryPanel"
	
	turn_history_panel.anchor_left = 1.0
	turn_history_panel.anchor_right = 1.0
	turn_history_panel.anchor_top = 0.0
	turn_history_panel.anchor_bottom = 1.0
	
	turn_history_panel.offset_left = -1700
	turn_history_panel.offset_right = -1110
	turn_history_panel.offset_top = 340
	turn_history_panel.offset_bottom = -300
	
	turn_history_panel.modulate = Color(0.424, 0.427, 0.439, 0.855)
	turn_history_panel.z_index = 100
	
	turn_history_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	turn_history_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	turn_history_panel.add_child(vbox)
	
	var hbox = HBoxContainer.new()
	hbox.name = "HBoxContainer"
	vbox.add_child(hbox)
	
	var title = Label.new()
	title.text = "Turn History"
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)
	
	var clear_btn = Button.new()
	clear_btn.name = "ClearButton"
	clear_btn.text = "Clear"
	hbox.add_child(clear_btn)
	
	var export_btn = Button.new()
	export_btn.name = "ExportButton"
	export_btn.text = "Export"
	hbox.add_child(export_btn)
	
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 0)
	hbox.add_child(close_btn)
	
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var tree = Tree.new()
	tree.name = "Tree"
	scroll.add_child(tree)
	
	add_child(turn_history_panel)
	
	turn_history_panel.history_tree = tree
	turn_history_panel.clear_button = clear_btn
	turn_history_panel.export_button = export_btn
	turn_history_panel.close_button = close_btn
	
	turn_history_panel.visible = true
	
	var show_btn = Button.new()
	show_btn.text = "📜 History"
	show_btn.position = Vector2(10, 10)
	show_btn.pressed.connect(_on_show_history_pressed)
	add_child(show_btn)

func _on_show_history_pressed() -> void:
	if turn_history_panel:
		turn_history_panel.visible = not turn_history_panel.visible

func setup_turn_history(history_manager: TurnHistoryManager) -> void:
	if turn_history_panel:
		turn_history_panel.setup(history_manager)

func _on_stack_updated(snapshot: Array):
	if snapshot.is_empty():
		stack_panel.hide()
	else:
		stack_panel.show()

func _input(event: InputEvent) -> void:
	# Если активен выбор цели
	if _target_selection_active:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				EventBus.target_selection_cancelled.emit()
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_LEFT:
				var clicked_object = _get_clicked_object()
				if clicked_object and clicked_object in _current_possible_targets:
					EventBus.target_selected.emit(clicked_object)
					_clear_target_selection()
					get_viewport().set_input_as_handled()
					return
		return
	
	# Если выбран Interrupt - обрабатываем клик по клетке
	if game_manager and game_manager.game_state.selected_interrupt_gear:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_object = _get_clicked_object()
			if clicked_object is Cell:
				var available = get_interrupt_available_cells(game_manager.game_state.selected_interrupt_gear)
				if clicked_object in available:
					GameLogger.debug("UI: Interrupt placement on valid cell %s" % Game.pos_to_chess(clicked_object.board_pos))
					interrupt_played.emit(game_manager.game_state.selected_interrupt_gear, clicked_object)
					get_viewport().set_input_as_handled()
					return
				else:
					GameLogger.debug("UI: Invalid cell for interrupt, cancelling selection")
					_cancel_interrupt_selection()
					get_viewport().set_input_as_handled()
					return
		return
	
	# Обычная обработка кликов для других действий
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_object = _get_clicked_object()
		if clicked_object is Gear and game_manager and not game_manager.stack_manager.is_stack_empty():
			# Проверяем, можно ли кликнуть по Gear (например, для снятия T)
			var cmd = TakeTCommand.new(clicked_object, 1, game_manager, game_manager.game_state)
			if cmd.can_execute():
				# Будет обработано в handle_gear_clicked
				pass

func _on_action_button_pressed() -> void:
	action_pressed.emit()

func _on_player_button_pressed(player_id: int) -> void:
	EventBus.player_icon_clicked.emit(player_id)

func update_player(active_player_id: int) -> void:
	_active_player_id = active_player_id
	player_label.text = "Active Player: " + str(active_player_id + 1)

func update_phase(phase: Game.GamePhase) -> void:
	var phase_names = [
		"Upkeep",
		"Draw",
		"Chain Building",
		"Swing Back",
		"Resolution",
		"End",
		"Cleanup"
	]
	phase_label.text = "Phase: " + phase_names[phase]

func update_t_pool(t0: int, t1: int) -> void:
	t0_label.text = "T: " + str(t0)
	t1_label.text = "T: " + str(t1)

func update_action_button(phase: Game.GamePhase, placed: bool, active_player_id: int, can_pass: bool, stack_empty: bool) -> void:
	if not stack_empty:
		action_button.disabled = true
		action_button.text = "Stack active"
		return
	
	match phase:
		Game.GamePhase.CHAIN_BUILDING:
			action_button.text = "Pass"
			action_button.disabled = not can_pass
		Game.GamePhase.SWING_BACK:
			action_button.text = "End Swing Back"
			action_button.disabled = false
		Game.GamePhase.CHAIN_RESOLUTION:
			action_button.text = "Skip"
			action_button.disabled = false
		_:
			action_button.text = "Action"
			action_button.disabled = true

func update_round(round: int) -> void:
	round_label.text = "Round: " + str(round)

func update_chain_length(length: int) -> void:
	chain_length_label.text = "Chain: " + str(length) + " G"

func update_prompt(text: String) -> void:
	prompt_label.text = text

func update_damage(damage0: int, damage1: int) -> void:
	damage0_label.text = str(damage0) + "/" + str(Game.MAX_DAMAGE)
	damage1_label.text = str(damage1) + "/" + str(Game.MAX_DAMAGE)

func update_hands(hand1: Array, hand2: Array, active_player_id: int, stack_empty: bool) -> void:
	for child in hand_container_player1.get_children():
		child.queue_free()
	for child in hand_container_player2.get_children():
		child.queue_free()
	
	fill_hand_container(hand_container_player1, hand1, active_player_id == 0, 0, stack_empty)
	fill_hand_container(hand_container_player2, hand2, active_player_id == 1, 1, stack_empty)

func _get_scaled_texture(texture: Texture2D, target_size: int) -> Texture2D:
	if not texture:
		return null
	var image = texture.get_image()
	if not image:
		return texture
	image.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func fill_hand_container(container: HBoxContainer, hand: Array, is_active: bool, player_id: int, stack_empty: bool) -> void:
	for gear in hand:
		var button = Button.new()
		var icon_texture = gear.texture_reverse
		if gear.owner_id == player_id:
			icon_texture = gear.texture_obverse
		
		if icon_texture:
			button.icon = _get_scaled_texture(icon_texture, 98)
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var type_line = gear.get_type_line()
		var abilities_text = gear.get_abilities_description()
		var speed_text = ""
		if gear.type == GameEnums.GearType.CREATURE and gear.speed > 0:
			speed_text = "\nSpeed: %d" % gear.speed
		
		var interrupt_cost_text = ""
		if gear.type == GameEnums.GearType.INTERRUPT:
			var cost = gear.get_interrupt_cost()
			interrupt_cost_text = "\nCost: %d T" % cost
		
		var text = "%s\n%s\nTocks: %d Ticks: %d Time: %d%s%s\n%s" % [
			gear.gear_name,
			type_line,
			gear.max_tocks,
			gear.max_ticks,
			gear.current_ticks,
			speed_text,
			interrupt_cost_text,
			abilities_text
		]
		button.text = text
		button.set_meta("gear", gear)
		
		# Определяем, можно ли использовать карту
		var can_use = false
		
		# В фазе Resolution Interrupt карты активны
		if gear.type == GameEnums.GearType.INTERRUPT and game_manager and game_manager.game_state.current_phase == Game.GamePhase.CHAIN_RESOLUTION:
			# Interrupt может сыграть игрок, у которого есть приоритет (не обязательно активный)
			# Проверяем, что waiting_for_player активен и priority_player совпадает с владельцем карты
			can_use = game_manager.game_state.waiting_for_player and game_manager.game_state.priority_player == player_id and game_manager.game_state.selected_interrupt_gear == null
			if can_use:
				GameLogger.debug("Interrupt card %s is ACTIVE for player %d" % [gear.gear_name, player_id])
			else:
				GameLogger.debug("Interrupt card %s is INACTIVE for player %d: waiting=%s, priority=%d, selected=%s" % [gear.gear_name, player_id, game_manager.game_state.waiting_for_player, game_manager.game_state.priority_player, game_manager.game_state.selected_interrupt_gear])
		# В фазе Chain Building обычные карты активны ТОЛЬКО в шаге Embed
		elif game_manager and game_manager.game_state.current_phase == Game.GamePhase.CHAIN_BUILDING:
			var phase_machine = game_manager.phase_machine
			if phase_machine and phase_machine.current_phase is ChainBuildingPhase:
				var chain_phase = phase_machine.current_phase as ChainBuildingPhase
				can_use = is_active and stack_empty and chain_phase.is_embed_step()
		else:
			can_use = is_active and stack_empty
		
		if can_use:
			button.pressed.connect(_on_hand_button_pressed.bind(gear))
			button.mouse_entered.connect(_on_hand_button_mouse_entered.bind(gear))
			button.mouse_exited.connect(_on_hand_button_mouse_exited)
			button.disabled = false
			button.modulate = Color.WHITE
		else:
			button.disabled = true
			button.modulate = Color(0.7, 0.7, 0.7)
		
		button.autowrap_mode = TextServer.AUTOWRAP_WORD
		button.custom_minimum_size = Vector2(220, 120)
		container.add_child(button)

func _on_hand_button_pressed(gear: Node2D) -> void:
	GameLogger.debug("UI._on_hand_button_pressed: gear=%s, type=%s" % [gear.gear_name, gear.type])
	
	# Если в фазе Resolution и это Interrupt, выбираем для Interrupt
	if game_manager and game_manager.game_state.current_phase == Game.GamePhase.CHAIN_RESOLUTION:
		if gear is Gear and gear.type == GameEnums.GearType.INTERRUPT:
			GameLogger.debug("Interrupt card clicked: waiting=%s, priority=%d, owner=%d" % [game_manager.game_state.waiting_for_player, game_manager.game_state.priority_player, gear.owner_id])
			if game_manager.game_state.waiting_for_player and game_manager.game_state.priority_player == gear.owner_id:
				GameLogger.debug("Selecting interrupt gear %s" % gear.gear_name)
				select_interrupt_gear(gear)
				return
			else:
				GameLogger.warning("Cannot play Interrupt - not your priority")
				return
	
	hand_gear_selected.emit(gear)

func _on_hand_button_mouse_entered(gear: Gear) -> void:
	var icon_texture
	if gear.owner_id == _active_player_id:
		icon_texture = gear.texture_obverse
	else:
		icon_texture = gear.texture_reverse
	tooltip_icon.texture = _get_scaled_texture(icon_texture, 98)
	
	var tooltip_text = gear.get_tooltip_text()
	if tooltip_label:
		tooltip_label.text = tooltip_text
		tooltip_panel.global_position = _adjust_tooltip_position(get_viewport().get_mouse_position())
		tooltip_panel.show()

func show_gear_tooltip(gear: Gear, mouse_pos: Vector2) -> void:
	var icon_texture = gear.sprite.texture
	tooltip_icon.texture = _get_scaled_texture(icon_texture, 98)
	tooltip_label.text = gear.get_tooltip_text()
	tooltip_panel.global_position = _adjust_tooltip_position(mouse_pos)
	tooltip_panel.show()

func _on_hand_button_mouse_exited() -> void:
	tooltip_panel.hide()

func highlight_gear(gear: Node2D) -> void:
	for button in hand_container_player1.get_children():
		if button.get_meta("gear") == gear:
			button.modulate = Color.YELLOW
			return
	for button in hand_container_player2.get_children():
		if button.get_meta("gear") == gear:
			button.modulate = Color.YELLOW
			return

func unhighlight_gear(gear: Node2D) -> void:
	for button in hand_container_player1.get_children():
		if button.get_meta("gear") == gear:
			button.modulate = Color.WHITE if not button.disabled else Color(0.7, 0.7, 0.7)
			return
	for button in hand_container_player2.get_children():
		if button.get_meta("gear") == gear:
			button.modulate = Color.WHITE if not button.disabled else Color(0.7, 0.7, 0.7)
			return

func clear_selection() -> void:
	for button in hand_container_player1.get_children():
		if button.disabled:
			button.modulate = Color(0.7, 0.7, 0.7)
		else:
			button.modulate = Color.WHITE
	for button in hand_container_player2.get_children():
		if button.disabled:
			button.modulate = Color(0.7, 0.7, 0.7)
		else:
			button.modulate = Color.WHITE

func hide_gear_tooltip() -> void:
	tooltip_panel.hide()

func _adjust_tooltip_position(mouse_pos: Vector2) -> Vector2:
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = tooltip_panel.get_combined_minimum_size()
	var offset = Vector2(20, 20)

	var x = mouse_pos.x + offset.x
	var y = mouse_pos.y + offset.y

	if x + panel_size.x > viewport_size.x:
		x = mouse_pos.x - panel_size.x - offset.x
	if x < 0:
		x = 0

	if y + panel_size.y > viewport_size.y:
		y = mouse_pos.y - panel_size.y - offset.y
	if y < 0:
		y = 0

	return Vector2(x, y)

func _on_log_message(level: int, message: String, timestamp: Dictionary) -> void:
	var should_show = false
	match level:
		0: should_show = filter_debug.button_pressed
		1: should_show = filter_info.button_pressed
		2: should_show = filter_warning.button_pressed
		3: should_show = filter_error.button_pressed
		4: should_show = true
	if not should_show:
		return
	
	var time_str = "%02d:%02d:%02d" % [timestamp.hour, timestamp.minute, timestamp.second]
	var color = _get_color_for_level(level)
	log_text.append_text("[color=%s][%s] %s[/color]\n" % [color, time_str, message])
	log_text.scroll_to_line(log_text.get_line_count() - 1)

func _get_color_for_level(level: int) -> String:
	match level:
		0: return "gray"
		1: return "white"
		2: return "yellow"
		3: return "red"
		4: return "#00FF00"
		_: return "white"

func _on_clear_log() -> void:
	log_text.text = ""

func _on_target_selection_requested(ability: Ability, source: Gear, possible_targets: Array, context: Dictionary) -> void:
	if _target_selection_active:
		GameLogger.debug("UI: target selection already active, ignoring new request for ability %s" % ability.ability_name)
		return
	_target_selection_active = true
	_current_possible_targets = possible_targets
	
	_highlight_possible_targets(possible_targets)
	
	var player_num = source.owner_id + 1
	var prompt_text = "Player %d: Select target for %s" % [player_num, ability.ability_name]
	prompt_label.text = prompt_text

func _on_target_selection_cancelled() -> void:
	_clear_target_selection()

func cancel_target_selection() -> void:
	if _target_selection_active:
		_clear_target_selection()
		EventBus.target_selection_cancelled.emit()

func _clear_target_selection() -> void:
	_target_selection_active = false
	_current_possible_targets.clear()
	_restore_highlights()
	prompt_label.text = ""

func _highlight_possible_targets(targets: Array) -> void:
	_original_colors.clear()
	for target in targets:
		if target is Cell:
			_original_colors[target] = target.sprite.modulate
			target.sprite.modulate = Color.GREEN
		elif target is Gear:
			_original_colors[target] = target.modulate
			target.modulate = Color.GREEN
			GameLogger.debug("Highlighting gear %s at %s" % [target.gear_name, Game.pos_to_chess(target.board_position)])
		elif target is Player:
			var button = player0_button if target.player_id == 0 else player1_button
			_original_colors[target] = button.modulate
			button.modulate = Color.GREEN

func _restore_highlights() -> void:
	for obj in _original_colors:
		if not is_instance_valid(obj):
			continue
		if obj is Cell:
			obj.sprite.modulate = _original_colors[obj]
		elif obj is Gear:
			obj.modulate = _original_colors[obj]
		elif obj is Player:
			var button = player0_button if obj.player_id == 0 else player1_button
			button.modulate = _original_colors[obj]
	_original_colors.clear()

func _get_clicked_object():
	var viewport = get_viewport()
	if not viewport:
		return null
	var camera = viewport.get_camera_2d()
	if not camera:
		return null
	var space_state = camera.get_viewport().get_world_2d().direct_space_state
	var mouse_pos = viewport.get_mouse_position()
	var params = PhysicsPointQueryParameters2D.new()
	params.position = mouse_pos
	params.collision_mask = 1
	var result = space_state.intersect_point(params)
	if result.size() > 0:
		var collider = result[0].collider
		if collider is Gear:
			return collider
		elif collider is Cell:
			if collider.occupied_gear:
				return collider.occupied_gear
			return collider
		elif collider.get_parent() is Cell:
			return collider.get_parent()
	return null

func is_target_selection_active() -> bool:
	return _target_selection_active

func is_valid_target(obj: Object) -> bool:
	return obj in _current_possible_targets

func select_interrupt_gear(gear: Gear) -> void:
	if not game_manager:
		GameLogger.error("UI: game_manager not set")
		return
	
	if game_manager.game_state.current_phase != Game.GamePhase.CHAIN_RESOLUTION:
		GameLogger.warning("Can only play Interrupt during resolution phase")
		return
	
	GameLogger.debug("Selecting interrupt gear %s for player %d" % [gear.gear_name, gear.owner_id])
	game_manager.game_state.selected_interrupt_gear = gear
	highlight_gear(gear)
	
	var available_cells = get_interrupt_available_cells(gear)
	GameLogger.debug("Available cells for interrupt: %d" % available_cells.size())
	for cell in available_cells:
		cell.sprite.modulate = Color(1, 0.5, 0)
	
	var cost = gear.get_interrupt_cost()
	prompt_label.text = "Select a cell adjacent to the resolving gear to place Interrupt (cost: %d T)" % cost

func get_interrupt_available_cells(gear: Gear) -> Array[Cell]:
	var result: Array[Cell] = []
	
	if not game_manager:
		return result
	
	var current_pos = game_manager.game_state.current_resolve_pos
	
	if current_pos == Vector2i(-1, -1):
		return result
	
	var board_manager = game_manager.board_manager
	var neighbors = board_manager.get_neighbors(current_pos)
	
	for pos in neighbors:
		var cell = board_manager.get_cell(pos)
		if cell and cell.is_empty():
			if (gear.owner_id == 0 and cell.is_white()) or (gear.owner_id == 1 and cell.is_black()):
				result.append(cell)
	
	return result

func _cancel_interrupt_selection() -> void:
	if game_manager and game_manager.game_state.selected_interrupt_gear:
		var gear = game_manager.game_state.selected_interrupt_gear
		var available_cells = get_interrupt_available_cells(gear)
		for cell in available_cells:
			if cell.is_white():
				cell.sprite.modulate = Color(1, 1, 1, 0.8)
			else:
				cell.sprite.modulate = Color(0.2, 0.2, 0.2, 0.8)
		
		unhighlight_gear(gear)
		game_manager.game_state.selected_interrupt_gear = null
		prompt_label.text = ""

func _on_batch_ordering_requested(player_id: int, entries: Array) -> void:
	if _batch_dialog and is_instance_valid(_batch_dialog):
		_batch_dialog.queue_free()
		_batch_dialog = null
	
	_batch_player_id = player_id
	_batch_entries = entries.duplicate()
	_batch_ordered = entries.duplicate()
	
	var dialog = Window.new()
	dialog.title = "Order Abilities (Player %d)" % (player_id + 1)
	dialog.size = Vector2(500, 300)
	dialog.exclusive = true
	dialog.unresizable = false
	dialog.wrap_controls = true
	add_child(dialog)
	dialog.popup_centered()
	_batch_dialog = dialog
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	dialog.add_child(vbox)
	
	var label = Label.new()
	label.text = "Arrange your triggered abilities (top will resolve last):"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var list_container = VBoxContainer.new()
	list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(list_container)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.disabled = false
	confirm_btn.pressed.connect(_on_batch_confirm.bind(list_container))
	vbox.add_child(confirm_btn)
	_batch_confirm_button = confirm_btn
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_batch_cancel)
	vbox.add_child(cancel_btn)
	
	_update_batch_list(list_container)

func _update_batch_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
	
	for i in range(_batch_ordered.size()):
		var entry = _batch_ordered[i]
		var hbox = HBoxContainer.new()
		container.add_child(hbox)
		
		var text = "%s from %s" % [entry.ability.ability_name, entry.source.gear_name]
		if entry.ability.target_type != GameEnums.TargetType.NO_TARGET:
			text += " (needs target)"
		var label = Label.new()
		label.text = text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)
		
		if i > 0:
			var up_btn = Button.new()
			up_btn.text = "↑"
			up_btn.pressed.connect(_move_entry.bind(i, -1, container))
			hbox.add_child(up_btn)
		if i < _batch_ordered.size() - 1:
			var down_btn = Button.new()
			down_btn.text = "↓"
			down_btn.pressed.connect(_move_entry.bind(i, 1, container))
			hbox.add_child(down_btn)

func _move_entry(index: int, delta: int, list_container: VBoxContainer) -> void:
	var new_index = index + delta
	if new_index < 0 or new_index >= _batch_ordered.size():
		return
	var temp = _batch_ordered[index]
	_batch_ordered[index] = _batch_ordered[new_index]
	_batch_ordered[new_index] = temp
	_update_batch_list(list_container)

func _on_batch_confirm(list_container: VBoxContainer) -> void:
	if _batch_dialog:
		_batch_dialog.queue_free()
		_batch_dialog = null
	EventBus.batch_ordering_completed.emit(_batch_ordered)

func _on_batch_cancel() -> void:
	if _batch_dialog:
		_batch_dialog.queue_free()
		_batch_dialog = null
	EventBus.batch_ordering_completed.emit(_batch_entries)
