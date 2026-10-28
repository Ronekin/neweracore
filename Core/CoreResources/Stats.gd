# Stats.gd — базовые характеристики с модификаторами.
# Контент (значения HP, силы стенда и т.п.) сюда не входит: мод задаёт числа,
# ядро только складывает базовые значения и модификаторы.

extends Reference

var base = {}
var modifiers = {}
var _cache = {}
var _dirty = true
var _next_id = 0


func setup(values = {}):
	base = {}
	if typeof(values) == TYPE_DICTIONARY:
		for key in values:
			base[key] = values[key]
	_dirty = true
	return self


func set_base(stat, value):
	base[stat] = value
	_dirty = true
	return value


func get_base(stat, fallback = 0.0):
	return base.get(stat, fallback)


func has_base(stat):
	return stat in base


func add_modifier(stat, value, options = {}):
	if typeof(options) != TYPE_DICTIONARY:
		options = {}
	_next_id += 1
	var id = options.get("id", "mod_" + str(_next_id))
	var entry = {
		"id": id,
		"stat": stat,
		"value": value,
		"flat": bool(options.get("flat", true)),
		"source": options.get("source", null),
		"priority": int(options.get("priority", 0))
	}
	modifiers[id] = entry
	_dirty = true
	return id


func add_flat(stat, value, options = {}):
	if typeof(options) != TYPE_DICTIONARY:
		options = {}
	options["flat"] = true
	return add_modifier(stat, value, options)


func add_percent(stat, value, options = {}):
	if typeof(options) != TYPE_DICTIONARY:
		options = {}
	options["flat"] = false
	return add_modifier(stat, value, options)


func remove_modifier(id):
	var existed = id in modifiers
	modifiers.erase(id)
	if existed:
		_dirty = true
	return existed


func remove_modifiers_from(source):
	var remove = []
	for id in modifiers:
		if modifiers[id].get("source") == source:
			remove.append(id)
	for id in remove:
		modifiers.erase(id)
	if not remove.empty():
		_dirty = true
	return remove.size()


func clear_modifiers(stat = null):
	if stat == null:
		modifiers.clear()
	else:
		var remove = []
		for id in modifiers:
			if modifiers[id].get("stat") == stat:
				remove.append(id)
		for id in remove:
			modifiers.erase(id)
	_dirty = true


func get(stat, fallback = 0.0):
	_recalculate()
	if stat in _cache:
		return _cache[stat]
	return fallback


func has(stat):
	_recalculate()
	return stat in _cache


func get_all():
	_recalculate()
	return _cache.duplicate(true)


func _recalculate():
	if not _dirty:
		return
	_cache = {}
	for stat in base:
		_cache[stat] = base[stat]
	var flat = {}
	var percent = {}
	for id in modifiers:
		var mod = modifiers[id]
		var stat = mod.get("stat", "")
		if not (stat in _cache):
			_cache[stat] = 0.0
		if bool(mod.get("flat", true)):
			flat[stat] = flat.get(stat, 0.0) + mod.get("value", 0.0)
		else:
			percent[stat] = percent.get(stat, 0.0) + mod.get("value", 0.0)
	for stat in flat:
		_cache[stat] = _cache.get(stat, 0.0) + flat[stat]
	for stat in percent:
		_cache[stat] = _cache.get(stat, 0.0) * (1.0 + percent[stat])
	_dirty = false


func to_dict():
	return {
		"base": base.duplicate(true),
		"modifiers": modifiers.duplicate(true)
	}


func from_dict(source):
	if typeof(source) != TYPE_DICTIONARY:
		return self
	base = {}
	modifiers = {}
	var source_base = source.get("base", {})
	if typeof(source_base) == TYPE_DICTIONARY:
		for key in source_base:
			base[key] = source_base[key]
	var source_mods = source.get("modifiers", {})
	if typeof(source_mods) == TYPE_DICTIONARY:
		for key in source_mods:
			var mod = source_mods[key]
			if typeof(mod) == TYPE_DICTIONARY:
				modifiers[key] = mod.duplicate(true)
	_dirty = true
	return self


func duplicate_stats():
	var copy = get_script().new()
	copy.from_dict(to_dict())
	return copy
