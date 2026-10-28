# Save.gd — версионированные JSON-сохранения New Era Core.
# Никакого знания о полях игрока: мод передаёт словарь, ядро кладёт его в
# конверт с версией и метаданными. Это позволяет мигрировать сейвы без
# фиксированного порядка store_var().

extends Reference

const FORMAT = "newera.save"
const CURRENT_VERSION = 2
const DEFAULT_DIR = "user://saves"
const EXTENSION = ".json"

var save_dir = DEFAULT_DIR
var logger = null
var auto_migrate = true


func _init():
	_ensure_dir()


func set_logger(value):
	logger = value
	return self


func set_save_dir(path):
	save_dir = str(path)
	while save_dir.ends_with("/"):
		save_dir = save_dir.substr(0, save_dir.length() - 1)
	_ensure_dir()
	return self


func get_save_dir():
	return save_dir


func _ensure_dir():
	var dir = Directory.new()
	if not dir.dir_exists(save_dir):
		dir.make_dir_recursive(save_dir)


func sanitize_slot(slot_id):
	var text = str(slot_id).strip_edges().to_lower()
	var result = ""
	for i in range(text.length()):
		var c = text[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			result += c
		else:
			result += "_"
	if result == "":
		result = "slot"
	return result


func get_slot_path(slot_id):
	return save_dir + "/" + sanitize_slot(slot_id) + EXTENSION


func get_path_slot(slot_id):
	return get_slot_path(slot_id)


func create_slot(slot_id, version = CURRENT_VERSION):
	return {
		"id": str(slot_id),
		"version": int(version),
		"path": get_slot_path(slot_id),
		"data": {}
	}


func save(slot_or_id, data):
	var slot = _resolve_slot(slot_or_id)
	if typeof(data) != TYPE_DICTIONARY:
		data = {}
	var envelope = {
		"format": FORMAT,
		"version": int(slot.get("version", CURRENT_VERSION)),
		"slot": str(slot.get("id", "")),
		"timestamp": OS.get_unix_time(),
		"datetime": OS.get_datetime(),
		"data": data
	}
	var path = str(slot.get("path", get_slot_path(slot.get("id", ""))))
	var f = File.new()
	if f.open(path, File.WRITE) != OK:
		_log_error("Cannot write save: " + path)
		return false
	f.store_string(JSON.print(envelope, "\t"))
	f.close()
	return true


func save_slot(slot_or_id, data):
	return save(slot_or_id, data)


func save_dict(slot_id, data):
	return save(slot_id, data)


func load(slot_or_id):
	var slot = _resolve_slot(slot_or_id)
	var path = str(slot.get("path", get_slot_path(slot.get("id", ""))))
	var f = File.new()
	if not f.file_exists(path):
		return null
	if f.open(path, File.READ) != OK:
		_log_error("Cannot read save: " + path)
		return null
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse(text)
	if parsed.error != OK:
		_log_error("Corrupted save JSON: " + path)
		return null
	var envelope = parsed.result
	if typeof(envelope) != TYPE_DICTIONARY:
		return null
	if not ("data" in envelope):
		return null
	var version = int(envelope.get("version", 1))
	var data = envelope.get("data", {})
	if auto_migrate and version < CURRENT_VERSION:
		data = migrate(data, version)
	return data


func load_slot(slot_or_id):
	return load(slot_or_id)


func load_dict(slot_id):
	return load(slot_id)


func raw_load(slot_id):
	var path = get_slot_path(slot_id)
	var f = File.new()
	if not f.file_exists(path) or f.open(path, File.READ) != OK:
		return null
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse(text)
	if parsed.error != OK:
		return null
	return parsed.result


func exists(slot_id):
	var f = File.new()
	return f.file_exists(get_slot_path(slot_id))


func exists_slot(slot_id):
	return exists(slot_id)


func slot_exists(slot_id):
	return exists(slot_id)


func delete(slot_id):
	var path = get_slot_path(slot_id)
	var dir = Directory.new()
	if dir.file_exists(path):
		return dir.remove(path) == OK
	return false


func delete_slot(slot_id):
	return delete(slot_id)


func list_slots():
	var result = []
	var dir = Directory.new()
	if dir.open(save_dir) != OK:
		return result
	dir.list_dir_begin(true, true)
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(EXTENSION):
			result.append(file_name.substr(0, file_name.length() - EXTENSION.length()))
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result


func list_saves():
	var result = []
	for slot_id in list_slots():
		var raw = raw_load(slot_id)
		if typeof(raw) == TYPE_DICTIONARY:
			result.append({
				"id": raw.get("slot", slot_id),
				"version": raw.get("version", 0),
				"timestamp": raw.get("timestamp", 0),
				"datetime": raw.get("datetime", {}),
				"path": get_slot_path(slot_id)
			})
	return result


func migrate(data, from_version):
	# Ядро не знает полей конкретной игры. Мод может переопределить поведение,
	# подписавшись на этот метод через свой класс-профиль, либо вызвать
	# Core.migrate_save(data, version, callback). Здесь только безопасная база.
	if from_version < 2 and typeof(data) == TYPE_DICTIONARY:
		if not ("save_version" in data):
			data["save_version"] = 2
	return data


func _resolve_slot(slot_or_id):
	if typeof(slot_or_id) == TYPE_DICTIONARY:
		var slot = slot_or_id.duplicate()
		if not ("id" in slot):
			slot["id"] = "slot"
		if not ("path" in slot):
			slot["path"] = get_slot_path(slot["id"])
		if not ("version" in slot):
			slot["version"] = CURRENT_VERSION
		return slot
	return create_slot(slot_or_id)


func _log_error(message):
	if logger != null:
		logger.error(message)
