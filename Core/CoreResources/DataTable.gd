# DataTable.gd — контейнер данных, а не реестр контента.
# Мод сам создаёт таблицы (предметы, враги, стенды) и передаёт их куда нужно.
# Ядро не сканирует папки и не регистрирует контент автоматически.

extends Reference

var rows = {}
var id_key = "id"
var source_path = ""


func setup(data = {}, key = "id"):
	rows = {}
	id_key = str(key)
	if typeof(data) == TYPE_DICTIONARY:
		for key_value in data:
			var row = data[key_value]
			if typeof(row) == TYPE_DICTIONARY:
				var copy = row.duplicate(true)
				copy[id_key] = key_value
				rows[key_value] = copy
	elif typeof(data) == TYPE_ARRAY:
		for row in data:
			if typeof(row) == TYPE_DICTIONARY and id_key in row:
				rows[row[id_key]] = row.duplicate(true)
	return self


func load_json(path, key = "id"):
	source_path = str(path)
	var f = File.new()
	if not f.file_exists(path):
		return self
	if f.open(path, File.READ) != OK:
		return self
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse(text)
	if parsed.error != OK or typeof(parsed.result) != TYPE_DICTIONARY:
		return self
	var data = parsed.result.get("rows", parsed.result)
	return setup(data, key)


func load_dict(data, key = "id"):
	return setup(data, key)


func add(id, row):
	if typeof(row) != TYPE_DICTIONARY:
		row = {}
	var copy = row.duplicate(true)
	copy[id_key] = id
	rows[id] = copy
	return copy


func get_row(id, fallback = null):
	if id in rows:
		return rows[id]
	return fallback


func get_value(id, field, fallback = null):
	var row = rows.get(id, null)
	if typeof(row) == TYPE_DICTIONARY:
		return row.get(field, fallback)
	return fallback


func has(id):
	return id in rows


func remove(id):
	var existed = id in rows
	rows.erase(id)
	return existed


func clear():
	rows.clear()


func ids():
	return rows.keys()


func all():
	return rows.duplicate(true)


func values():
	return rows.values()


func size():
	return rows.size()


func find(field, value):
	var result = []
	for id in rows:
		var row = rows[id]
		if typeof(row) == TYPE_DICTIONARY and row.get(field) == value:
			result.append(row)
	return result


func first(field, value):
	for id in rows:
		var row = rows[id]
		if typeof(row) == TYPE_DICTIONARY and row.get(field) == value:
			return row
	return null


func filter(predicate):
	var result = []
	for id in rows:
		if predicate.call_func(rows[id]):
			result.append(rows[id])
	return result


func merge(other, overwrite = false):
	if typeof(other) == TYPE_DICTIONARY:
		for id in other:
			if overwrite or not (id in rows):
				rows[id] = other[id].duplicate(true) if typeof(other[id]) == TYPE_DICTIONARY else other[id]
	return self


func validate(required_fields = []):
	var errors = []
	for id in rows:
		var row = rows[id]
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("Row %s is not a dictionary" % str(id))
			continue
		for field in required_fields:
			if not (field in row):
				errors.append("Row %s missing field %s" % [str(id), str(field)])
	return errors


func get_source_path():
	return source_path
