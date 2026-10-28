# Utils.gd — небольшие общие функции, которые не заслуживают отдельного сервиса.

extends Reference

var rng = RandomNumberGenerator.new()


func _init():
	rng.randomize()


func deep_duplicate(value):
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return value


func merge_dict(base, override, deep = true):
	var result = base.duplicate(true) if typeof(base) == TYPE_DICTIONARY else {}
	if typeof(override) != TYPE_DICTIONARY:
		return result
	for key in override:
		if deep and typeof(result.get(key)) == TYPE_DICTIONARY and typeof(override[key]) == TYPE_DICTIONARY:
			result[key] = merge_dict(result[key], override[key], true)
		else:
			result[key] = deep_duplicate(override[key])
	return result


func dict_get_any(dictionary, keys, fallback = null):
	if typeof(dictionary) != TYPE_DICTIONARY:
		return fallback
	for key in keys:
		if key in dictionary:
			return dictionary[key]
	return fallback


func array_remove_value(array, value):
	for i in range(array.size() - 1, -1, -1):
		if array[i] == value:
			array.remove(i)


func array_unique(array):
	var seen = {}
	var result = []
	for item in array:
		var key = var2str(item)
		if not (key in seen):
			seen[key] = true
			result.append(item)
	return result


func array_find_by(array, field, value):
	for i in range(array.size()):
		var item = array[i]
		if typeof(item) == TYPE_DICTIONARY and item.get(field) == value:
			return i
	return -1


func clamp_value(value, minimum, maximum):
	return min(max(value, minimum), maximum)


func approach(current, target, delta):
	if current < target:
		return min(current + delta, target)
	return max(current - delta, target)


func move_toward(current, target, delta):
	return approach(current, target, delta)


func remap_value(value, in_min, in_max, out_min, out_max):
	if in_max == in_min:
		return out_min
	return out_min + (value - in_min) * (out_max - out_min) / (in_max - in_min)


func snap_to_grid(value, grid):
	if grid <= 0.0:
		return value
	return floor(value / grid) * grid


func random_range(from, to):
	return rng.randf_range(from, to)


func random_int(from, to):
	return rng.randi_range(from, to)


func random_pick(array):
	if typeof(array) != TYPE_ARRAY or array.empty():
		return null
	return array[rng.randi_range(0, array.size() - 1)]


func shuffle(array):
	if typeof(array) != TYPE_ARRAY:
		return array
	for i in range(array.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp
	return array


func chance(probability):
	return rng.randf() < probability


func sign_value(value):
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0


func is_finite_number(value):
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_REAL:
		return false
	return not is_nan(value) and not is_inf(value)


func is_finite_vector(value):
	return typeof(value) == TYPE_VECTOR2 and is_finite_number(value.x) and is_finite_number(value.y)


func safe_connect(signal_owner, signal_name, target, method, binds = []):
	if signal_owner == null or target == null:
		return false
	if not signal_owner.is_connected(signal_name, target, method):
		return signal_owner.connect(signal_name, target, method, binds) == OK
	return true


func safe_disconnect(signal_owner, signal_name, target, method):
	if signal_owner == null or target == null:
		return false
	if signal_owner.is_connected(signal_name, target, method):
		signal_owner.disconnect(signal_name, target, method)
		return true
	return false


func find_child(node, name, recursive = true):
	if node == null:
		return null
	if node.has_node(name):
		return node.get_node(name)
	if not recursive:
		return null
	for child in node.get_children():
		var found = find_child(child, name, true)
		if found != null:
			return found
	return null


func get_node_or_null(root, path):
	if root == null:
		return null
	return root.get_node_or_null(path)


func load_json(path):
	var f = File.new()
	if not f.file_exists(path):
		return null
	if f.open(path, File.READ) != OK:
		return null
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse(text)
	if parsed.error != OK:
		return null
	return parsed.result


func save_json(path, data, indent = "\t"):
	var dir = Directory.new()
	var folder = path.get_base_dir()
	if folder != "" and not dir.dir_exists(folder):
		dir.make_dir_recursive(folder)
	var f = File.new()
	if f.open(path, File.WRITE) != OK:
		return false
	f.store_string(JSON.print(data, indent))
	f.close()
	return true


func read_text(path, fallback = ""):
	var f = File.new()
	if not f.file_exists(path) or f.open(path, File.READ) != OK:
		return fallback
	var text = f.get_as_text()
	f.close()
	return text


func write_text(path, text):
	var dir = Directory.new()
	var folder = path.get_base_dir()
	if folder != "" and not dir.dir_exists(folder):
		dir.make_dir_recursive(folder)
	var f = File.new()
	if f.open(path, File.WRITE) != OK:
		return false
	f.store_string(text)
	f.close()
	return true


func sanitize_id(value, fallback = "item"):
	var text = str(value).strip_edges().to_lower()
	var result = ""
	for i in range(text.length()):
		var c = text[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			result += c
		else:
			result += "_"
	if result == "":
		result = str(fallback)
	return result


func format_time(seconds):
	var total = int(max(0, seconds))
	var hours = total / 3600
	var minutes = (total % 3600) / 60
	var secs = total % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]


func format_number(value):
	var text = str(int(value))
	var result = ""
	var count = 0
	for i in range(text.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = " " + result
		result = text[i] + result
		count += 1
	return result


func direction_to_angle(direction):
	return direction.angle()


func vector_from_angle(angle, length = 1.0):
	return Vector2(cos(angle), sin(angle)) * length


func lerp_vector(from, to, weight):
	return from.linear_interpolate(to, weight)


func screen_center():
	var viewport = Engine.get_main_loop().get_root()
	return viewport.size * 0.5


func get_scene_path(node):
	if node == null:
		return ""
	var scene = node.get_tree().current_scene
	return scene.filename if scene != null else ""
