# Settings.gd — простые пользовательские настройки в JSON.
# Не содержит конкретных настроек игры: мод задаёт ключи и значения.

extends Reference

const DEFAULT_PATH = "user://settings.json"

var path = DEFAULT_PATH
var values = {}
var auto_save = true


func _init():
	load_settings()


func load_settings():
	values = {}
	var f = File.new()
	if not f.file_exists(path):
		return self
	if f.open(path, File.READ) != OK:
		return self
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse(text)
	if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
		values = parsed.result
	return self


func save_settings():
	var f = File.new()
	if f.open(path, File.WRITE) != OK:
		return false
	f.store_string(JSON.print(values, "\t"))
	f.close()
	return true


func get_value(key, fallback = null):
	return values.get(key, fallback)


func set_value(key, value):
	values[key] = value
	if auto_save:
		save_settings()
	return value


func has(key):
	return key in values


func remove(key):
	values.erase(key)
	if auto_save:
		save_settings()


func reset():
	values = {}
	if auto_save:
		save_settings()
	return self


func get_all():
	return values.duplicate(true)
