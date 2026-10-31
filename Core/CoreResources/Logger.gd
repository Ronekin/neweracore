# Logger.gd — опциональное логирование New Era Core.
# Ядро не должно шуметь в консоль без необходимости: логирование включается
# настройками проекта или через Core.set_logging(true/false).

extends Reference

const LEVEL_NONE = 0
const LEVEL_ERROR = 1
const LEVEL_WARN = 2
const LEVEL_INFO = 3
const LEVEL_DEBUG = 4

var enabled = true
var level = LEVEL_INFO
var prefix = "[Core]"
var echo_to_console = true
var mirror_to_file = false
var log_file = "user://core.log"
var max_file_size = 512 * 1024

var _file = null
var _file_path = ""


func configure(options):
	if typeof(options) != TYPE_DICTIONARY:
		return self
	if "enabled" in options:
		enabled = bool(options["enabled"])
	if "level" in options:
		level = int(options["level"])
	if "prefix" in options:
		prefix = str(options["prefix"])
	if "echo" in options:
		echo_to_console = bool(options["echo"])
	if "file" in options:
		log_file = str(options["file"])
		mirror_to_file = log_file != ""
	if "max_file_size" in options:
		max_file_size = int(options["max_file_size"])
	return self


func set_enabled(value):
	enabled = bool(value)
	return self


func is_enabled():
	return enabled


func set_level(value):
	level = int(value)
	return self


func error(message, context = null):
	_emit(LEVEL_ERROR, "ERROR", message, context)


func warn(message, context = null):
	_emit(LEVEL_WARN, "WARN", message, context)


func info(message, context = null):
	_emit(LEVEL_INFO, "INFO", message, context)


func debug(message, context = null):
	_emit(LEVEL_DEBUG, "DEBUG", message, context)


func _emit(message_level, tag, message, context = null):
	if not enabled or message_level > level:
		return
	var text = "%s %s: %s" % [prefix, tag, str(message)]
	if context != null:
		text += " | " + str(context)
	if echo_to_console:
		if message_level == LEVEL_ERROR:
			printerr(text)
		elif message_level == LEVEL_WARN:
			printerr(text)
		else:
			print(text)
	if mirror_to_file:
		_write_file(text)


func _write_file(text):
	var path = log_file if _file_path == "" else _file_path
	var f = File.new()
	var exists = f.file_exists(path)
	var size = 0
	if exists:
		if f.open(path, File.READ) == OK:
			size = f.get_len()
			f.close()
		if size > max_file_size:
			var dir = Directory.new()
			dir.remove(path)
			exists = false
	var mode = File.READ_WRITE if exists else File.WRITE
	if f.open(path, mode) != OK:
		return
	if exists:
		f.seek_end()
	f.store_line(text)
	f.close()
	_file_path = path


func clear_file():
	if _file_path == "":
		_file_path = log_file
	var dir = Directory.new()
	if dir.file_exists(_file_path):
		dir.remove(_file_path)
	return true
