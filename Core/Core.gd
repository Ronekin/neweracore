# Core.gd — единый фасад New Era Core (Godot 3.5.1).
# Автозагрузка: Core
#
# Правило API: мод вызывает Core.add_slot(...), Core.save_game(...),
# Core.change_scene(...), Core.play_sfx(...) и т.п. Никаких Core.storage.*,
# Core.entity.* и никаких префиксов вроде physics_set_gravity.
#
# Ядро не содержит контента SEDWC: ни стендов, ни врагов, ни предметов.

extends Node

const CORE_VERSION = "2.0.0"
const CORE_BUILD = 1

const LoggerScript = preload("res://Core/CoreResources/Logger.gd")
const StorageScript = preload("res://Core/CoreResources/Storage.gd")
const EntityScript = preload("res://Core/CoreResources/Entity.gd")
const AbilityMassiveScript = preload("res://Core/CoreResources/AbilityMassive.gd")
const InputScript = preload("res://Core/CoreResources/Input.gd")
const ResourceScript = preload("res://Core/CoreResources/Resource.gd")
const PhysicsScript = preload("res://Core/CoreResources/Physics.gd")
const SaveScript = preload("res://Core/CoreResources/Save.gd")
const SceneScript = preload("res://Core/CoreResources/Scene.gd")
const AudioScript = preload("res://Core/CoreResources/Audio.gd")
const UtilsScript = preload("res://Core/CoreResources/Utils.gd")
const StatsScript = preload("res://Core/CoreResources/Stats.gd")
const DamageInfoScript = preload("res://Core/CoreResources/DamageInfo.gd")
const DataTableScript = preload("res://Core/CoreResources/DataTable.gd")
const SettingsScript = preload("res://Core/CoreResources/Settings.gd")
const StateMachineScript = preload("res://Core/CoreResources/StateMachine.gd")
const PoolScript = preload("res://Core/CoreResources/Pool.gd")

var logger = null
var _storage = null
var _input = null
var _resources = null
var _physics = null
var _save = null
var _scene = null
var _audio = null
var _utils = null
var _settings = null

var _initialized = false


func _ready():
	_initialize()


func _initialize():
	if _initialized:
		return
	logger = LoggerScript.new()
	var logging_enabled = bool(_project_setting("newera/logging/enabled", true))
	var logging_level = int(_project_setting("newera/logging/level", 2))
	var logging_file = str(_project_setting("newera/logging/file", ""))
	logger.configure({
		"enabled": logging_enabled,
		"level": logging_level,
		"prefix": "[Core]",
		"echo": true,
		"file": logging_file
	})

	_storage = StorageScript.new().create_storage("dict")
	_input = InputScript.new()
	_resources = ResourceScript.new().set_logger(logger)
	_save = SaveScript.new().set_logger(logger)
	_utils = UtilsScript.new()
	_settings = SettingsScript.new()

	_physics = PhysicsScript.new()
	_physics.name = "PhysicsService"
	_physics.set_logger(logger)
	add_child(_physics)

	_scene = SceneScript.new()
	_scene.name = "SceneService"
	_scene.set_logger(logger)
	add_child(_scene)

	_audio = AudioScript.new()
	_audio.name = "AudioService"
	_audio.set_logger(logger)
	add_child(_audio)

	_initialized = true
	logger.debug("New Era Core v%s build %s initialized" % [CORE_VERSION, str(CORE_BUILD)])


# ============================================================
# ВЕРСИЯ И ЛОГИРОВАНИЕ
# ============================================================

func get_version():
	return CORE_VERSION


func get_build():
	return CORE_BUILD


func is_initialized():
	return _initialized


func set_logging(enabled):
	logger.set_enabled(enabled)
	return enabled


func is_logging():
	return logger.is_enabled()


func set_log_level(level):
	logger.set_level(level)


func set_log_file(path):
	if logger.mirror_to_file and logger.log_file == path:
		return
	logger.mirror_to_file = str(path) != ""
	logger.log_file = str(path)


func log(message, context = null):
	logger.info(message, context)


func warn(message, context = null):
	logger.warn(message, context)


func error(message, context = null):
	logger.error(message, context)


func debug_log(message, context = null):
	logger.debug(message, context)


# ============================================================
# STORAGE
# ============================================================

func create_storage(type = "dict", value_type = null, default_value = null):
	return StorageScript.new().create_storage(type, value_type, default_value)


func add_slot(slot_id, value = null):
	return _storage.add_slot(slot_id, value)


func get_slot(slot_id, fallback = null):
	if _storage.has_slot(slot_id):
		return _storage.get_slot(slot_id)
	return fallback


func set_slot(slot_id, value):
	return _storage.set_slot(slot_id, value)


func has_slot(slot_id):
	return _storage.has_slot(slot_id)


func remove_slot(slot_id):
	return _storage.remove_slot(slot_id)


func clear_storage():
	_storage.clear()


func storage_size():
	return _storage.size()


func storage_keys():
	return _storage.keys()


func storage_all():
	return _storage.get_all()


func storage_snapshot():
	return _storage.snapshot()


func storage_restore(data):
	return _storage.restore(data)


# ============================================================
# ENTITY / DAMAGE / TIMERS
# ============================================================

func create_entity(params = {}, script_path = "", parent = null):
	var script = EntityScript
	if str(script_path) != "":
		script = load(script_path)
	if script == null:
		error("Entity script not found: " + str(script_path))
		return null
	var entity = script.new()
	if entity == null:
		return null
	if entity.has_method("create"):
		entity.create(params)
	var target = parent
	if target == null:
		target = get_tree().current_scene if get_tree() != null else null
	if target == null:
		target = self
	target.add_child(entity)
	return entity


func spawn_entity(params = {}, script_path = "", parent = null):
	return create_entity(params, script_path, parent)


func create_ability(params = {}, script_path = "", parent = null):
	var script = AbilityMassiveScript
	if str(script_path) != "":
		script = load(script_path)
	if script == null:
		error("Ability script not found: " + str(script_path))
		return null
	var ability = script.new()
	if ability.has_method("create"):
		ability.create(params)
	var target = parent
	if target == null:
		target = get_tree().current_scene if get_tree() != null else null
	if target == null:
		target = self
	target.add_child(ability)
	return ability


func apply_damage(target, amount, info = null):
	if target == null or not target.has_method("take_damage"):
		return null
	var data = info
	if typeof(data) != TYPE_DICTIONARY:
		data = {}
	data["amount"] = amount
	return target.take_damage(data)


func heal_entity(target, amount):
	if target == null or not target.has_method("heal"):
		return 0.0
	return target.heal(amount)


func kill_entity(target, source = null):
	if target != null and target.has_method("kill"):
		target.kill(source)


func get_entities(team = ""):
	if get_tree() == null:
		return []
	if str(team) == "":
		return get_tree().get_nodes_in_group("entity")
	return get_tree().get_nodes_in_group("team_" + str(team))


func find_entity(team = ""):
	var entities = get_entities(team)
	return entities[0] if not entities.empty() else null


func create_timer(owner, timer_name, wait_time, target, method, args = [], one_shot = true):
	if owner == null or not owner.has_method("add_timer"):
		return null
	return owner.add_timer(timer_name, wait_time, target, method, args, one_shot)


func cancel_timer(owner, timer_name):
	if owner != null and owner.has_method("cancel_timer"):
		owner.cancel_timer(timer_name)


func create_stats(values = {}):
	return StatsScript.new().setup(values)


func make_damage(amount, options = {}):
	var data = options if typeof(options) == TYPE_DICTIONARY else {}
	data["amount"] = amount
	return DamageInfoScript.new(data)


# ============================================================
# INPUT
# ============================================================

func register_action(action_id, input_type = "key", input_data = null):
	return _input.create_action(action_id, input_type, input_data)


func register_key(action_id, scancode):
	return _input.register_key(action_id, scancode)


func remove_action(action_id):
	_input.remove_action(action_id)


func has_action(action_id):
	return _input.has_action(action_id)


func actions():
	return _input.get_all_actions()


func is_pressed(action_id):
	return _input.is_pressed(action_id)


func is_just_pressed(action_id):
	return _input.is_just_pressed(action_id)


func is_just_released(action_id):
	return _input.is_just_released(action_id)


func get_axis(negative_action, positive_action):
	return _input.get_axis(negative_action, positive_action)


func get_vector(negative_x, positive_x, negative_y, positive_y, deadzone = -1.0):
	return _input.get_vector(negative_x, positive_x, negative_y, positive_y, deadzone)


func get_mouse_position():
	return _input.get_mouse_position()


func press_action(action_id):
	_input.press(action_id)


func release_action(action_id):
	_input.release(action_id)


func set_mouse_mode(mode):
	_input.set_mouse_mode(mode)


func get_mouse_mode():
	return _input.get_mouse_mode()


# ============================================================
# RESOURCE
# ============================================================

func load_resource(path, type_hint = ""):
	return _resources.load_resource(path, type_hint)


func load_texture(path):
	return _resources.load_texture(path)


func load_scene_resource(path):
	return _resources.load_scene(path)


func load_sound(path):
	return _resources.load_sound(path)


func unload_resource(path):
	return _resources.unload(path)


func clear_resource_cache():
	_resources.clear_cache()


func cached_resources():
	return _resources.get_cached()


func resource_exists(path):
	return _resources.exists(path)


func load_json_data(path):
	return _utils.load_json(path)


func save_json_data(path, data):
	return _utils.save_json(path, data)


# ============================================================
# PHYSICS
# ============================================================

func set_gravity(gravity_vector):
	return _physics.set_gravity(gravity_vector)


func get_gravity():
	return _physics.get_gravity()


func set_target_fps(fps):
	_physics.set_target_fps(fps)


func get_target_fps():
	return _physics.get_target_fps()


func set_pixel_snap(enabled):
	_physics.set_pixel_snap(enabled)


func set_debug_collisions(enabled):
	_physics.set_debug_collisions(enabled)


func raycast(from_pos, to_pos, collision_mask = 1, exclude = [], collide_with_bodies = true, collide_with_areas = false):
	return _physics.raycast(from_pos, to_pos, collision_mask, exclude, collide_with_bodies, collide_with_areas)


func line_of_sight(from_pos, to_pos, collision_mask = 1, exclude = []):
	return _physics.line_of_sight(from_pos, to_pos, collision_mask, exclude)


func intersect_point(point, collision_mask = 1, exclude = []):
	return _physics.intersect_point(point, collision_mask, exclude)


func overlap_circle(center, radius, collision_mask = 1, exclude = []):
	return _physics.overlap_circle(center, radius, collision_mask, exclude)


func overlap_rect(rect, collision_mask = 1, exclude = []):
	return _physics.overlap_rect(rect, collision_mask, exclude)


func physics_settings():
	return _physics.get_settings()


# ============================================================
# SAVE
# ============================================================

func save_game(slot_id, data):
	return _save.save(slot_id, data)


func load_game(slot_id):
	return _save.load(slot_id)


func save_exists(slot_id):
	return _save.exists(slot_id)


func delete_save(slot_id):
	return _save.delete(slot_id)


func list_saves():
	return _save.list_saves()


func list_save_slots():
	return _save.list_slots()


func save_path(slot_id):
	return _save.get_slot_path(slot_id)


func set_save_dir(path):
	_save.set_save_dir(path)


# ============================================================
# SCENE
# ============================================================

func change_scene(path, use_deferred = true):
	return _scene.change_scene(path, use_deferred)


func reload_scene():
	return _scene.reload_current()


func current_scene():
	return _scene.get_current_scene()


func current_scene_path():
	return _scene.get_current_path()


func scene_is_loading():
	return _scene.is_loading()


func load_scene(path):
	return _scene.load_scene(path)


# ============================================================
# AUDIO
# ============================================================

func play_music(path_or_stream, loop = true, volume = 1.0, fade = 0.0):
	return _audio.play_music(path_or_stream, loop, volume, fade)


func stop_music(fade = 0.0):
	_audio.stop_music(fade)


func pause_music():
	_audio.pause_music()


func resume_music():
	_audio.resume_music()


func is_music_playing():
	return _audio.is_music_playing()


func play_sfx(path_or_stream, volume = 1.0, pitch = 1.0, bus = ""):
	return _audio.play_sfx(path_or_stream, volume, pitch, bus)


func stop_all_sfx():
	_audio.stop_all_sfx()


func set_master_volume(value):
	_audio.set_master_volume(value)


func set_music_volume(value):
	_audio.set_music_volume(value)


func set_sfx_volume(value):
	_audio.set_sfx_volume(value)


func set_bus_volume(bus_name, value):
	_audio.set_bus_volume(bus_name, value)


func set_bus_muted(bus_name, muted):
	_audio.set_bus_muted(bus_name, muted)


# ============================================================
# SETTINGS / DATA / UTILS
# ============================================================

func create_data_table(data = {}, id_key = "id"):
	return DataTableScript.new().setup(data, id_key)


func load_data_table(path, id_key = "id"):
	return DataTableScript.new().load_json(path, id_key)


func get_setting(key, fallback = null):
	return _settings.get_value(key, fallback)


func set_setting(key, value):
	return _settings.set_value(key, value)


func save_settings():
	return _settings.save_settings()


func reload_settings():
	return _settings.load_settings()


func create_state_machine(owner, definitions = {}, initial = ""):
	return StateMachineScript.new().setup(owner, definitions, initial)


func create_pool(scene, container, prewarm = 0):
	return PoolScript.new().setup(scene, container, prewarm)


func deep_duplicate(value):
	return _utils.deep_duplicate(value)


func merge_dict(base, override):
	return _utils.merge_dict(base, override)


func random_range(from, to):
	return _utils.random_range(from, to)


func random_int(from, to):
	return _utils.random_int(from, to)


func random_pick(array):
	return _utils.random_pick(array)


func shuffle(array):
	return _utils.shuffle(array)


func chance(probability):
	return _utils.chance(probability)


func approach(current, target, delta):
	return _utils.approach(current, target, delta)


func clamp_value(value, minimum, maximum):
	return _utils.clamp_value(value, minimum, maximum)


func format_time(seconds):
	return _utils.format_time(seconds)


func format_number(value):
	return _utils.format_number(value)


func sanitize_id(value, fallback = "id"):
	return _utils.sanitize_id(value, fallback)


func safe_connect(owner, signal_name, target, method, binds = []):
	return _utils.safe_connect(owner, signal_name, target, method, binds)


func safe_disconnect(owner, signal_name, target, method):
	return _utils.safe_disconnect(owner, signal_name, target, method)


func find_child(node, child_name, recursive = true):
	return _utils.find_child(node, child_name, recursive)


func _project_setting(key, fallback = null):
	if ProjectSettings.has_setting(key):
		return ProjectSettings.get_setting(key)
	return fallback
