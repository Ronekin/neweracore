# Resource.gd — загрузка и кэширование ресурсов.
# Не содержит путей к конкретному контенту и не регистрирует сцены.

extends Reference

var cache = {}
var logger = null
var use_cache = true


func set_logger(value):
	logger = value
	return self


func load_resource(path, type_hint = ""):
	if path == null or str(path) == "":
		return null
	var key = str(path)
	if use_cache and key in cache:
		return cache[key]
	if not ResourceLoader.exists(key):
		_log_warn("Resource not found: " + key)
		return null
	var resource = load(key)
	if resource != null:
		if type_hint != "" and not _matches_type(resource, type_hint):
			_log_warn("Resource has unexpected type: " + key)
		if use_cache:
			cache[key] = resource
	return resource


func load_texture(path):
	return load_resource(path, "Texture")


func load_scene(path):
	return load_resource(path, "PackedScene")


func load_sound(path):
	return load_resource(path, "AudioStream")


func load_material(path):
	return load_resource(path, "Material")


func load_shader(path):
	return load_resource(path, "Shader")


func get_resource(path):
	return load_resource(path)


func preload_resource(path):
	return load_resource(path)


func exists(path):
	return ResourceLoader.exists(str(path))


func unload(path):
	var key = str(path)
	if key in cache:
		cache.erase(key)
		return true
	return false


func release(path):
	return unload(path)


func clear_cache():
	cache.clear()


func get_cached():
	return cache.keys()


func get_cache_size():
	return cache.size()


func has(path):
	return str(path) in cache


func _matches_type(resource, type_hint):
	match str(type_hint):
		"Texture":
			return resource is Texture
		"PackedScene":
			return resource is PackedScene
		"AudioStream":
			return resource is AudioStream
		"Material":
			return resource is Material
		"Shader":
			return resource is Shader
	return true


func _log_warn(message):
	if logger != null:
		logger.warn(message)
