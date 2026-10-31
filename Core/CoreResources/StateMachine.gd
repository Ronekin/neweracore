# StateMachine.gd — небольшой конечный автомат без знания о контенте.
# Мод описывает состояния и правила переходов; ядро только переключает их.

extends Reference

signal state_changed(old_state, new_state, data)

var states = {}
var current = ""
var previous = ""
var time_in_state = 0.0
var target = null
var locked = false


func setup(owner, definitions = {}, initial = ""):
	target = owner
	states = {}
	if typeof(definitions) == TYPE_DICTIONARY:
		for name in definitions:
			add_state(name, definitions[name])
	initial = str(initial)
	if initial != "":
		force(initial)
	return self


func add_state(name, definition = {}):
	states[str(name)] = definition if typeof(definition) == TYPE_DICTIONARY else {}
	return self


func remove_state(name):
	if current == name:
		current = ""
	states.erase(name)
	return self


func has_state(name):
	return name in states


func force(name, data = {}):
	if not (name in states):
		return false
	var old = current
	_exit(old)
	previous = old
	current = name
	time_in_state = 0.0
	_enter(name, data)
	emit_signal("state_changed", old, current, data)
	return true


func change(name, data = {}):
	if locked:
		return false
	if not (name in states):
		return false
	if current == name:
		return false
	if current != "":
		var current_def = states.get(current, {})
		var allowed = current_def.get("transitions", null)
		if typeof(allowed) == TYPE_ARRAY and not allowed.empty() and not (name in allowed):
			return false
	return force(name, data)


func update(delta):
	time_in_state += delta
	if current == "":
		return
	var definition = states.get(current, {})
	if bool(definition.get("automatic", false)):
		var next_state = str(definition.get("next", ""))
		var duration = float(definition.get("duration", 0.0))
		if next_state != "" and duration > 0.0 and time_in_state >= duration:
			change(next_state)


func is_state(name):
	return current == name


func get_current():
	return current


func get_previous():
	return previous


func _enter(name, data):
	var definition = states.get(name, {})
	var method = str(definition.get("on_enter", ""))
	if target != null and method != "" and target.has_method(method):
		target.call(method, data)


func _exit(name):
	if name == "":
		return
	var definition = states.get(name, {})
	var method = str(definition.get("on_exit", ""))
	if target != null and method != "" and target.has_method(method):
		target.call(method, current)


func serialize():
	return {
		"current": current,
		"previous": previous,
		"time_in_state": time_in_state
	}


func deserialize(data):
	if typeof(data) != TYPE_DICTIONARY:
		return self
	previous = str(data.get("previous", ""))
	time_in_state = float(data.get("time_in_state", 0.0))
	var state_name = str(data.get("current", ""))
	if state_name != "" and state_name in states:
		current = state_name
	return self
