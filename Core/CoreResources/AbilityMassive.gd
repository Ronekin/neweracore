# AbilityMassive.gd — фундамент для стендов, техник, спеков и любых наборов
# способностей. Это Node2D, поэтому конкретный стенд/техника могут наследовать
# его и одновременно находиться в сцене.
#
# Ядро хранит способности, кулдауны и пассивки. Что такое "Tusk" или "Dio" —
# решает только мод.

extends Node2D
class_name AbilityMassive

signal ability_registered(ability_id, data)
signal ability_removed(ability_id)
signal ability_activated(ability_id, context)
signal ability_deactivated(ability_id)
signal ability_triggered(ability_id, context)
signal cooldown_started(ability_id, duration)
signal cooldown_finished(ability_id)
signal passive_applied(effect_id, value)
signal passive_removed(effect_id)

export var ability_name = "AbilityMassive"
export var am_type = "ability"
export var active = true
export var auto_update_cooldowns = true
export var cast_range = 200.0
export var can_move_while_casting = false
export var auto_attack = false
export var fusion_compatible = false

var owner_entity = null
var abilities = {}
var cooldowns = {}
var passives = {}
var current_cast = ""
var current_context = {}
var cast_time_left = 0.0
var cast_duration = 0.0
var _last_ready = {}


func _ready():
	if abilities.empty():
		_scan_ability_methods()
	set_process(auto_update_cooldowns)


func _process(delta):
	if auto_update_cooldowns:
		update_cooldowns(delta)
	if cast_time_left > 0.0:
		cast_time_left = max(0.0, cast_time_left - delta)
		if cast_time_left == 0.0:
			finish_cast()


func create(values = {}):
	if typeof(values) != TYPE_DICTIONARY:
		return self
	if "name" in values:
		ability_name = str(values["name"])
	if "type" in values:
		am_type = str(values["type"])
	if "owner" in values:
		set_owner_entity(values["owner"])
	if "position" in values:
		position = values["position"]
	if "active" in values:
		active = bool(values["active"])
	if "cast_range" in values:
		cast_range = float(values["cast_range"])
	if "can_move_while_casting" in values:
		can_move_while_casting = bool(values["can_move_while_casting"])
	if "auto_attack" in values:
		auto_attack = bool(values["auto_attack"])
	if "fusion_compatible" in values:
		fusion_compatible = bool(values["fusion_compatible"])
	if "abilities" in values:
		register_abilities(values["abilities"])
	if "passives" in values and typeof(values["passives"]) == TYPE_DICTIONARY:
		for key in values["passives"]:
			apply_passive(key, values["passives"][key])
	return self


func set_owner_entity(entity):
	owner_entity = entity
	return self


func register_ability(ability_id, data = {}):
	var id = str(ability_id)
	if typeof(data) != TYPE_DICTIONARY:
		data = {}
	var definition = data.duplicate(true)
	if not ("cooldown" in definition):
		definition["cooldown"] = 0.0
	if not ("damage" in definition):
		definition["damage"] = 0.0
	if not ("range" in definition):
		definition["range"] = cast_range
	if not ("cast_time" in definition):
		definition["cast_time"] = 0.0
	definition["id"] = id
	abilities[id] = definition
	if not (id in cooldowns):
		cooldowns[id] = 0.0
	emit_signal("ability_registered", id, definition)
	return definition


func register_abilities(data):
	if typeof(data) == TYPE_DICTIONARY:
		for id in data:
			register_ability(id, data[id])
	elif typeof(data) == TYPE_ARRAY:
		for item in data:
			if typeof(item) == TYPE_DICTIONARY:
				var id = item.get("id", "")
				if id != "":
					register_ability(id, item)
	return self


func unregister_ability(ability_id):
	var id = str(ability_id)
	var existed = id in abilities
	abilities.erase(id)
	cooldowns.erase(id)
	if current_cast == id:
		current_cast = ""
	if existed:
		emit_signal("ability_removed", id)
	return existed


func has_ability(ability_id):
	return str(ability_id) in abilities


func get_ability(ability_id, fallback = null):
	return abilities.get(str(ability_id), fallback)


func get_abilities():
	return abilities.duplicate(true)


func is_ready(ability_id):
	var id = str(ability_id)
	if not (id in abilities):
		return false
	return float(cooldowns.get(id, 0.0)) <= 0.0


func get_cooldown(ability_id):
	return float(cooldowns.get(str(ability_id), 0.0))


func start_cooldown(ability_id, duration = -1.0):
	var id = str(ability_id)
	if duration < 0.0:
		var data = abilities.get(id, {})
		duration = float(data.get("cooldown", 0.0))
	if duration <= 0.0:
		cooldowns[id] = 0.0
		return 0.0
	cooldowns[id] = float(duration)
	emit_signal("cooldown_started", id, duration)
	return duration


func reduce_cooldown(ability_id, amount):
	var id = str(ability_id)
	if not (id in cooldowns):
		return 0.0
	cooldowns[id] = max(0.0, float(cooldowns[id]) - float(amount))
	if cooldowns[id] == 0.0:
		emit_signal("cooldown_finished", id)
	return cooldowns[id]


func reset_cooldown(ability_id):
	cooldowns[str(ability_id)] = 0.0


func reset_all_cooldowns():
	for id in cooldowns:
		cooldowns[id] = 0.0


func update_cooldowns(delta):
	for id in cooldowns:
		if cooldowns[id] > 0.0:
			cooldowns[id] = max(0.0, float(cooldowns[id]) - delta)
			if cooldowns[id] == 0.0:
				emit_signal("cooldown_finished", id)


func apply_passive(effect_id, value):
	var id = str(effect_id)
	passives[id] = value
	emit_signal("passive_applied", id, value)
	return value


func remove_passive(effect_id):
	var id = str(effect_id)
	var existed = id in passives
	passives.erase(id)
	if existed:
		emit_signal("passive_removed", id)
	return existed


func get_passive(effect_id, fallback = null):
	return passives.get(str(effect_id), fallback)


func has_passive(effect_id):
	return str(effect_id) in passives


func can_cast(ability_id):
	if not active or not (str(ability_id) in abilities):
		return false
	return is_ready(ability_id)


func activate(ability_id, context = {}):
	var id = str(ability_id)
	if not can_cast(id):
		return false
	var data = abilities.get(id, {})
	current_cast = id
	current_context = context if typeof(context) == TYPE_DICTIONARY else {}
	cast_duration = float(data.get("cast_time", 0.0))
	cast_time_left = cast_duration
	emit_signal("ability_activated", id, current_context)
	if cast_duration <= 0.0:
		finish_cast()
	return true


func finish_cast():
	if current_cast == "":
		return
	var id = current_cast
	var context = current_context
	current_cast = ""
	cast_time_left = 0.0
	cast_duration = 0.0
	current_context = {}
	emit_signal("ability_triggered", id, context)
	start_cooldown(id)
	return id


func cancel_cast():
	if current_cast == "":
		return
	var id = current_cast
	current_cast = ""
	current_context = {}
	cast_time_left = 0.0
	cast_duration = 0.0
	emit_signal("ability_deactivated", id)


func deactivate(ability_id):
	var id = str(ability_id)
	if current_cast == id:
		cancel_cast()
	emit_signal("ability_deactivated", id)


func set_active(value):
	active = bool(value)
	if not active:
		cancel_cast()


func get_current_cast():
	return current_cast


func get_cast_progress():
	if cast_duration <= 0.0:
		return 1.0
	return 1.0 - clamp(cast_time_left / cast_duration, 0.0, 1.0)


func clone():
	var copy = get_script().new()
	copy.ability_name = ability_name
	copy.am_type = am_type
	copy.active = active
	copy.cast_range = cast_range
	copy.can_move_while_casting = can_move_while_casting
	copy.auto_attack = auto_attack
	copy.fusion_compatible = fusion_compatible
	copy.abilities = abilities.duplicate(true)
	copy.cooldowns = cooldowns.duplicate(true)
	copy.passives = passives.duplicate(true)
	return copy


func _scan_ability_methods():
	var methods = []
	for item in get_method_list():
		var method_name = str(item.get("name", ""))
		if method_name.begins_with("ability_"):
			methods.append(method_name)
	return methods


func serialize():
	return {
		"ability_name": ability_name,
		"am_type": am_type,
		"active": active,
		"abilities": abilities.duplicate(true),
		"cooldowns": cooldowns.duplicate(true),
		"passives": passives.duplicate(true)
	}


func deserialize(data):
	if typeof(data) != TYPE_DICTIONARY:
		return self
	ability_name = str(data.get("ability_name", ability_name))
	am_type = str(data.get("am_type", am_type))
	active = bool(data.get("active", active))
	if typeof(data.get("abilities")) == TYPE_DICTIONARY:
		abilities = data["abilities"].duplicate(true)
	if typeof(data.get("cooldowns")) == TYPE_DICTIONARY:
		cooldowns = data["cooldowns"].duplicate(true)
	if typeof(data.get("passives")) == TYPE_DICTIONARY:
		passives = data["passives"].duplicate(true)
	return self
