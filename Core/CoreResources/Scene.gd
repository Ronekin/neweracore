# Scene.gd — смена сцен без знания о конкретных картах и переходах мода.
# Мод может обернуть вызов своей анимацией, а ядро даёт безопасную базу.

extends Node

signal scene_change_started(path)
signal scene_changed(path)
signal scene_change_failed(path, error)

var current_path = ""
var pending_path = ""
var loading = false
var logger = null


func set_logger(value):
	logger = value
	return self


func load_scene(path):
	if not ResourceLoader.exists(str(path)):
		_log_error("Scene not found: " + str(path))
		return null
	return load(str(path))


func change_scene(path, use_deferred = true):
	var target = str(path)
	if not ResourceLoader.exists(target):
		_log_error("Cannot change to missing scene: " + target)
		emit_signal("scene_change_failed", target, ERR_FILE_NOT_FOUND)
		return false
	if loading:
		_log_warn("Scene change already in progress: " + pending_path)
		return false
	loading = true
	pending_path = target
	emit_signal("scene_change_started", target)
	if use_deferred:
		call_deferred("_deferred_change", target)
	else:
		_deferred_change(target)
	return true


func _deferred_change(path):
	var error = get_tree().change_scene(path)
	if error != OK:
		loading = false
		pending_path = ""
		_log_error("change_scene failed for " + path + " (" + str(error) + ")")
		emit_signal("scene_change_failed", path, error)
		return
	current_path = path
	loading = false
	pending_path = ""
	call_deferred("_emit_changed", path)


func _emit_changed(path):
	emit_signal("scene_changed", path)


func change_scene_packed(scene, path = ""):
	if scene == null or not scene is PackedScene:
		return false
	var error = get_tree().change_scene_to(scene)
	if error != OK:
		emit_signal("scene_change_failed", path, error)
		return false
	current_path = path
	emit_signal("scene_changed", path)
	return true


func reload_current():
	var scene = get_current_scene()
	if scene == null:
		return false
	var path = scene.filename
	if path == "":
		path = current_path
	if path == "":
		return false
	return change_scene(path, false)


func get_current_scene():
	if get_tree() == null:
		return null
	return get_tree().current_scene


func get_current_path():
	var scene = get_current_scene()
	if scene != null and scene.filename != "":
		return scene.filename
	return current_path


func is_loading():
	return loading


func get_pending_path():
	return pending_path


func _log_error(message):
	if logger != null:
		logger.error(message)
	else:
		printerr("[Core] " + str(message))


func _log_warn(message):
	if logger != null:
		logger.warn(message)
