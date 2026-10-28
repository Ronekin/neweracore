# Storage.gd — универсальное хранилище слотов New Era Core.
# Не знает ни про предметы, ни про стенды, ни про квесты. Мод сам решает,
# что положить в слот. Это обычный Reference, поэтому Storage можно держать
# внутри любого Node, Entity или AbilityMassive.

extends Reference

var container_type = "dict"
var data_type = 0
var default_value = null
var data = {}

var _initialized = false


func create_storage(type = "dict", value_type = null, value_default = null):
	container_type = str(type)
	if value_type != null:
		data_type = int(value_type)
	default_value = value_default
	if not _initialized or typeof(data) != TYPE_DICTIONARY:
		data = {}
	_initialized = true
	return self


func add_slot(slot_id, value = null):
	if value == null and default_value != null:
		value = _duplicate_value(default_value)
	data[slot_id] = value
	return slot_id


func get_slot(slot_id):
	return data.get(slot_id, null)


func get_or(slot_id, fallback):
	if slot_id in data:
		return data[slot_id]
	return fallback


func set_slot(slot_id, value):
	data[slot_id] = value
	return value


func update_slot(slot_id, updater, fallback = null):
	var current = data.get(slot_id, fallback)
	var result = updater.call_func(current) if updater is FuncRef else updater
	data[slot_id] = result
	return result


func has(slot_id):
	return slot_id in data


func has_slot(slot_id):
	return slot_id in data


func remove_slot(slot_id):
	var existed = slot_id in data
	data.erase(slot_id)
	return existed


func erase(slot_id):
	return remove_slot(slot_id)


func clear():
	data.clear()


func size():
	return data.size()


func is_empty():
	return data.empty()


func keys():
	return data.keys()


func values():
	return data.values()


func get_all():
	return duplicate_data(data)


func snapshot():
	return duplicate_data(data)


func restore(source):
	data = duplicate_data(source) if typeof(source) == TYPE_DICTIONARY else {}
	_initialized = true
	return self


func merge(source, overwrite = true):
	if typeof(source) != TYPE_DICTIONARY:
		return self
	for key in source:
		if overwrite or not (key in data):
			data[key] = duplicate_data(source[key])
	return self


func increment(slot_id, amount = 1):
	var current = data.get(slot_id, 0)
	if typeof(current) != TYPE_INT and typeof(current) != TYPE_REAL:
		current = 0
	var result = current + amount
	data[slot_id] = result
	return result


func append(slot_id, value):
	var list = data.get(slot_id, null)
	if typeof(list) != TYPE_ARRAY:
		list = []
		data[slot_id] = list
	list.append(value)
	return list


func find(slot_id, predicate):
	var list = data.get(slot_id, null)
	if typeof(list) != TYPE_ARRAY:
		return null
	for item in list:
		if predicate.call_func(item):
			return item
	return null


func first_key(fallback = null):
	for key in data:
		return key
	return fallback


func duplicate_data(value):
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return value


func _duplicate_value(value):
	return duplicate_data(value)
