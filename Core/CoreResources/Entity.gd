# Entity.gd — фундаментальная сущность New Era Core (Godot 3.5.1).
# Намеренно наследует KinematicBody2D: тогда мод может строить цепочки
# Entity -> Enemy -> Gyro и использовать физику/позицию напрямую.
#
# Ядро даёт только жизненный цикл, здоровье, урон, параметры, таймеры и
# элементарное движение. AI, анимации, лут и имена врагов — это мод.

extends KinematicBody2D
class_name Entity

signal spawned(entity)
signal despawned(entity)
signal health_changed(current, maximum)
signal damaged(info)
signal healed(amount, source)
signal died(info)
signal state_changed(old_state, new_state)
signal param_changed(key, value)

const StatsScript = preload("res://Core/CoreResources/Stats.gd")
const TimerHostScript = preload("res://Core/CoreResources/TimerHost.gd")
const DamageInfoScript = preload("res://Core/CoreResources/DamageInfo.gd")

export var max_hp = 100.0
export var move_speed = 120.0
export var team = "neutral"
export var invulnerable = false
export var destroy_on_death = false
export var use_base_movement = false

var health = 0.0
var alive = true
var velocity = Vector2.ZERO
var facing = Vector2.RIGHT
var look_direction = "Right"
var state = "idle"
var params = {}
var tags = []
var stats = null
var timer_host = null
var rng = null
var knockback = Vector2.ZERO
var knockback_decay = 1400.0
var last_damage = null
var damage_cooldown = 0.0
var damage_cooldown_time = 0.0
var invulnerable_time = 0.0

var _components_ready = false
var _initialized = false
var _last_state = ""


func _init():
	_ensure_components()


func _ready():
	initialize()


func _ensure_components():
	if stats == null:
		stats = StatsScript.new()
	if timer_host == null:
		timer_host = TimerHostScript.new()
		timer_host.name = "Timers"
		add_child(timer_host)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()


func create(values = {}):
	if typeof(values) != TYPE_DICTIONARY:
		return self
	if "name" in values:
		name = str(values["name"])
	if "max_hp" in values:
		max_hp = float(values["max_hp"])
	if "health" in values:
		health = float(values["health"])
	if "move_speed" in values:
		move_speed = float(values["move_speed"])
	if "team" in values:
		team = str(values["team"])
	if "position" in values:
		position = values["position"]
	if "visible" in values:
		visible = bool(values["visible"])
	if "tags" in values and typeof(values["tags"]) == TYPE_ARRAY:
		tags = values["tags"].duplicate()
	if "stats" in values and typeof(values["stats"]) == TYPE_DICTIONARY:
		stats.setup(values["stats"])
	if "params" in values and typeof(values["params"]) == TYPE_DICTIONARY:
		params = values["params"].duplicate(true)
	for key in values:
		if not key in ["name", "max_hp", "health", "move_speed", "team", "position", "visible", "tags", "stats", "params"]:
			params[key] = values[key]
	return self


func initialize():
	_ensure_components()
	if not _initialized:
		if max_hp <= 0.0:
			max_hp = 1.0
		if health <= 0.0:
			health = max_hp
		alive = health > 0.0
		if not is_in_group("entity"):
			add_to_group("entity")
		if not is_in_group("team_" + team):
			add_to_group("team_" + team)
		_initialized = true
		emit_signal("spawned", self)
		emit_signal("health_changed", health, max_hp)
	return self


func set_max_hp(value, refill = false):
	max_hp = max(1.0, float(value))
	if refill:
		health = max_hp
	health = min(health, max_hp)
	emit_signal("health_changed", health, max_hp)


func set_health(value, emit = true):
	var old = health
	health = clamp(float(value), 0.0, max_hp)
	if emit and old != health:
		emit_signal("health_changed", health, max_hp)
	if health <= 0.0 and alive:
		die(last_damage)
	return health


func get_health():
	return health


func get_health_ratio():
	if max_hp <= 0.0:
		return 0.0
	return clamp(health / max_hp, 0.0, 1.0)


func heal(amount, source = null):
	if not alive or amount <= 0.0:
		return 0.0
	var before = health
	health = min(max_hp, health + float(amount))
	var applied = health - before
	if applied > 0.0:
		emit_signal("healed", applied, source)
		emit_signal("health_changed", health, max_hp)
	return applied


func take_damage(amount_or_info, source = null, options = null):
	var info = _make_damage_info(amount_or_info, source, options)
	info.target = self
	if not alive or info.amount <= 0.0:
		return info
	if invulnerable and not info.ignore_invuln:
		info.blocked = true
		info.absorbed = info.amount
		emit_signal("damaged", info)
		return info
	if damage_cooldown > 0.0 and not info.ignore_cooldown:
		info.blocked = true
		info.absorbed = info.amount
		emit_signal("damaged", info)
		return info
	info = _before_damage(info)
	if info.blocked or info.amount <= 0.0:
		emit_signal("damaged", info)
		return info
	if info.type == "heal":
		heal(info.amount, info.source)
		return info
	var applied = max(0.0, info.amount - float(stats.get("defense", 0.0)))
	if info.crit:
		applied *= 1.5
	info.applied = applied
	health = max(0.0, health - applied)
	last_damage = info
	if info.knockback > 0.0:
		var direction = info.direction
		if direction == Vector2.ZERO:
			direction = (global_position - info.position)
		if direction != Vector2.ZERO:
			apply_knockback(direction.normalized(), info.knockback)
	if damage_cooldown_time > 0.0:
		damage_cooldown = damage_cooldown_time
	emit_signal("health_changed", health, max_hp)
	emit_signal("damaged", info)
	if health <= 0.0:
		info.killed = true
		die(info)
	return info


func damage(amount, source = null, options = null):
	return take_damage(amount, source, options)


func _make_damage_info(amount_or_info, source, options):
	if typeof(amount_or_info) == TYPE_OBJECT and amount_or_info.get_script() == DamageInfoScript:
		return amount_or_info
	if typeof(amount_or_info) == TYPE_DICTIONARY:
		var from_dict = DamageInfoScript.new(amount_or_info)
		if source != null and from_dict.source == null:
			from_dict.source = source
		return from_dict
	var info = DamageInfoScript.new(float(amount_or_info))
	info.source = source
	if typeof(options) == TYPE_DICTIONARY:
		info.apply(options)
	return info


func _before_damage(info):
	return info


func _on_death(info):
	pass


func die(info = null):
	if not alive:
		return
	alive = false
	health = 0.0
	velocity = Vector2.ZERO
	set_state("dead")
	if info != null:
		info.killed = true
	emit_signal("health_changed", health, max_hp)
	emit_signal("died", info)
	_on_death(info)
	if destroy_on_death:
		destroy()


func kill(source = null):
	die(DamageInfoScript.new({"amount": health, "source": source, "ignore_invuln": true}))


func revive(health_value = -1.0):
	alive = true
	health = max_hp if health_value < 0.0 else clamp(health_value, 0.0, max_hp)
	set_state("idle")
	emit_signal("health_changed", health, max_hp)


func set_state(new_state, data = null):
	new_state = str(new_state)
	if new_state == state:
		return
	var old = state
	_last_state = old
	state = new_state
	emit_signal("state_changed", old, state)


func get_state():
	return state


func set_param(key, value):
	params[key] = value
	emit_signal("param_changed", key, value)


func get_param(key, fallback = null):
	if key in params:
		return params[key]
	if stats != null and key in stats:
		return stats.get(key)
	return fallback


func has_param(key):
	return key in params or (stats != null and key in stats)


func remove_param(key):
	var existed = key in params
	params.erase(key)
	return existed


func get_all_params():
	return params.duplicate(true)


func set_stat(key, value):
	stats.set_base(key, value)


func get_stat(key, fallback = 0.0):
	return stats.get(key, fallback)


func add_tag(tag):
	if not (tag in tags):
		tags.append(tag)
		add_to_group("tag_" + str(tag))


func has_tag(tag):
	return tag in tags


func is_hostile_to(other):
	if other == null or other == self:
		return false
	var other_team = str(other.team) if "team" in other else "neutral"
	return team != other_team and team != "neutral" and other_team != "neutral"


func set_team(value):
	team = str(value)
	if is_inside_tree() and not is_in_group("team_" + team):
		add_to_group("team_" + team)


func face_direction(direction):
	if direction.x != 0.0:
		facing = Vector2(sign(direction.x), 0)
		look_direction = "Right" if direction.x > 0.0 else "Left"


func face_position(target_position):
	face_direction(target_position - global_position)


func get_facing_direction():
	return facing


func apply_knockback(direction, force):
	knockback = direction.normalized() * force


func update_knockback(delta):
	if knockback.length() <= 1.0:
		knockback = Vector2.ZERO
		return Vector2.ZERO
	var movement = knockback * delta
	knockback = knockback.move_toward(Vector2.ZERO, knockback_decay * delta)
	return movement


func move(delta, input_velocity = null):
	if use_base_movement:
		velocity = input_velocity if input_velocity != null else velocity
		velocity += update_knockback(delta)
		velocity = move_and_slide(velocity)
	return velocity


func distance_to(other):
	if other == null:
		return INF
	return global_position.distance_to(other.global_position)


func direction_to(other):
	if other == null:
		return Vector2.ZERO
	return (other.global_position - global_position).normalized()


func add_timer(name, wait_time, target, method, args = [], one_shot = true):
	_ensure_components()
	return timer_host.start(name, wait_time, target, method, args, one_shot)


func add_timer_once(name, wait_time, target, method, args = []):
	return add_timer(name, wait_time, target, method, args, true)


func cancel_timer(name):
	if timer_host != null:
		timer_host.cancel(name)


func clear_timers():
	if timer_host != null:
		timer_host.cancel_all()


func set_invulnerable(value, duration = 0.0):
	invulnerable = bool(value)
	invulnerable_time = duration


func _physics_process(delta):
	tick(delta)


func tick(delta):
	if damage_cooldown > 0.0:
		damage_cooldown = max(0.0, damage_cooldown - delta)
	if invulnerable_time > 0.0:
		invulnerable_time = max(0.0, invulnerable_time - delta)
		if invulnerable_time == 0.0:
			invulnerable = false


func serialize():
	return {
		"name": name,
		"health": health,
		"max_hp": max_hp,
		"alive": alive,
		"state": state,
		"team": team,
		"position": [global_position.x, global_position.y],
		"params": params.duplicate(true),
		"tags": tags.duplicate(),
		"stats": stats.to_dict()
	}


func deserialize(data):
	if typeof(data) != TYPE_DICTIONARY:
		return self
	if "health" in data:
		health = float(data["health"])
	if "max_hp" in data:
		max_hp = float(data["max_hp"])
	if "alive" in data:
		alive = bool(data["alive"])
	if "state" in data:
		state = str(data["state"])
	if "team" in data:
		team = str(data["team"])
	if "params" in data and typeof(data["params"]) == TYPE_DICTIONARY:
		params = data["params"].duplicate(true)
	if "tags" in data and typeof(data["tags"]) == TYPE_ARRAY:
		tags = data["tags"].duplicate()
	if "stats" in data and typeof(data["stats"]) == TYPE_DICTIONARY:
		stats.from_dict(data["stats"])
	var pos = data.get("position", null)
	if typeof(pos) == TYPE_ARRAY and pos.size() >= 2:
		global_position = Vector2(float(pos[0]), float(pos[1]))
	return self


func destroy():
	alive = false
	clear_timers()
	if is_inside_tree():
		queue_free()


func _exit_tree():
	if timer_host != null:
		timer_host.cancel_all()
	emit_signal("despawned", self)
