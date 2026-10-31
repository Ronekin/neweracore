# Spawner.gd — базовый спавнер сцены с интервалом и лимитом живых объектов.
# Он не знает, кто именно спавнится: мод задаёт PackedScene и параметры.

extends Node2D
class_name CoreSpawner

signal spawned(node)
signal despawned(node)

export var scene = null
export var interval = 2.0
export var max_alive = 8
export var auto_start = false
export var spawn_on_ready = false
export var spawn_offset = Vector2.ZERO
export var enemy_team = "enemy"
export var spawn_params = {}

var alive_nodes = []
var _timer = 0.0
var running = false


func _ready():
	if auto_start:
		start()
	if spawn_on_ready:
		spawn()


func start():
	running = true
	_timer = interval


func stop():
	running = false


func is_running():
	return running


func _process(delta):
	if not running:
		return
	_cleanup()
	if alive_nodes.size() >= max_alive:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval
		spawn()


func spawn(params = null):
	if scene == null:
		return null
	var values = spawn_params if params == null else params
	var node = scene.instance()
	if node == null:
		return null
	node.position = position + spawn_offset
	if node.has_method("create") and typeof(values) == TYPE_DICTIONARY:
		node.create(values)
	get_parent().add_child(node)
	alive_nodes.append(node)
	emit_signal("spawned", node)
	return node


func _cleanup():
	for i in range(alive_nodes.size() - 1, -1, -1):
		var node = alive_nodes[i]
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			alive_nodes.remove(i)
			emit_signal("despawned", node)


func clear():
	for node in alive_nodes.duplicate():
		if is_instance_valid(node):
			node.queue_free()
	alive_nodes.clear()


func get_alive_count():
	_cleanup()
	return alive_nodes.size()
