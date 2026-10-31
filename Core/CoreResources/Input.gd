# Input.gd — тонкая обёртка над InputMap/Input Godot 3.5.
# Не дублирует состояние кнопок вручную: источник истины — движок.
# Мод может регистрировать действия из кода или использовать project.godot.

extends Reference

var _actions = {}


func create_action(action_id, input_type = "key", input_data = null):
	var action = str(action_id)
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if input_data != null:
		var event = _make_event(input_type, input_data)
		if event != null:
			InputMap.action_add_event(action, event)
	_actions[action] = true
	return action


func register_action(action_id, event):
	var action = str(action_id)
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if event is InputEvent:
		InputMap.action_add_event(action, event)
	_actions[action] = true
	return action


func register_key(action_id, scancode):
	var event = InputEventKey.new()
	event.scancode = int(scancode)
	return register_action(action_id, event)


func register_mouse(action_id, button_index):
	var event = InputEventMouseButton.new()
	event.button_index = int(button_index)
	return register_action(action_id, event)


func register_joy_button(action_id, button_index):
	var event = InputEventJoypadButton.new()
	event.button_index = int(button_index)
	return register_action(action_id, event)


func _make_event(input_type, input_data):
	match str(input_type):
		"key", "keyboard":
			var event = InputEventKey.new()
			event.scancode = int(input_data)
			return event
		"mouse":
			var event = InputEventMouseButton.new()
			event.button_index = int(input_data)
			return event
		"joy", "joy_button", "gamepad":
			var event = InputEventJoypadButton.new()
			event.button_index = int(input_data)
			return event
		"joy_motion", "axis":
			var event = InputEventJoypadMotion.new()
			if typeof(input_data) == TYPE_DICTIONARY:
				event.axis = int(input_data.get("axis", 0))
				event.axis_value = float(input_data.get("value", 1.0))
			return event
	return null


func has_action(action_id):
	return InputMap.has_action(str(action_id))


func remove_action(action_id):
	var action = str(action_id)
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	_actions.erase(action)


func get_all_actions():
	return InputMap.get_actions()


func get_actions():
	return get_all_actions()


func is_pressed(action_id):
	return Input.is_action_pressed(str(action_id))


func is_action_pressed(action_id):
	return is_pressed(action_id)


func is_just_pressed(action_id):
	return Input.is_action_just_pressed(str(action_id))


func is_action_just_pressed(action_id):
	return is_just_pressed(action_id)


func is_just_released(action_id):
	return Input.is_action_just_released(str(action_id))


func is_action_just_released(action_id):
	return is_just_released(action_id)


func get_strength(action_id):
	return Input.get_action_strength(str(action_id))


func get_axis(negative_action, positive_action):
	return Input.get_axis(str(negative_action), str(positive_action))


func get_vector(negative_x, positive_x, negative_y, positive_y, deadzone = -1.0):
	return Input.get_vector(str(negative_x), str(positive_x), str(negative_y), str(positive_y), deadzone)


func get_mouse_position():
	return get_viewport().get_mouse_position()


func is_mouse_pressed(button_index = 1):
	return Input.is_mouse_button_pressed(int(button_index))


func get_viewport():
	var tree = Engine.get_main_loop()
	if tree != null and tree is SceneTree:
		return tree.get_root()
	return null


func set_mouse_mode(mode):
	Input.set_mouse_mode(mode)


func get_mouse_mode():
	return Input.get_mouse_mode()


func press(action_id):
	if InputMap.has_action(str(action_id)):
		Input.action_press(str(action_id))


func release(action_id):
	if InputMap.has_action(str(action_id)):
		Input.action_release(str(action_id))
