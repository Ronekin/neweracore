# Pool.gd — простой пул узлов для снарядов, эффектов и UI-элементов.
# Не знает, что именно пулится: мод передаёт PackedScene и контейнер.

extends Reference

var scene = null
var container = null
var create_missing = true
var reset_method = ""
var free_items = []
var used_items = []


func setup(packed_scene, parent, prewarm = 0):
	scene = packed_scene
	container = parent
	if prewarm > 0:
		prewarm_count(prewarm)
	return self


func prewarm_count(count):
	for i in range(count):
		var item = _instantiate()
		if item != null:
			_release_item(item)
	return self


func acquire():
	while not free_items.empty():
		var item = free_items.pop_back()
		if is_instance_valid(item):
			used_items.append(item)
			if item.has_method("on_pool_acquire"):
				item.on_pool_acquire()
			return item
	if not create_missing:
		return null
	var created = _instantiate()
	if created != null:
		used_items.append(created)
		if created.has_method("on_pool_acquire"):
			created.on_pool_acquire()
	return created


func release(item):
	if item == null:
		return false
	var index = used_items.find(item)
	if index >= 0:
		used_items.remove(index)
	_release_item(item)
	return true


func release_all():
	for item in used_items.duplicate():
		release(item)
	return self


func _instantiate():
	if scene == null:
		return null
	var item = scene.instance()
	if item == null:
		return null
	if container != null:
		container.add_child(item)
	return item


func _release_item(item):
	if not is_instance_valid(item):
		return
	if reset_method != "" and item.has_method(reset_method):
		item.call(reset_method)
	if item is Node:
		item.visible = false
		if item.has_method("on_pool_release"):
			item.on_pool_release()
	free_items.append(item)


func clear():
	free_items.clear()
	used_items.clear()


func get_free_count():
	return free_items.size()


func get_used_count():
	return used_items.size()
