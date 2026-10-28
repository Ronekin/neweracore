# Hitbox.gd — Area2D, которая наносит унифицированный урон.
# Мод задаёт damage/team/маску; ядро убирает повторяющиеся area_entered.

extends Area2D
class_name CoreHitbox

signal hit(target, info)

export var damage = 10.0
export var damage_type = "physical"
export var team = "neutral"
export var once_per_target = false
export var hit_cooldown = 0.0
export var active = true
export var knockback = 0.0

var source = null
var hit_targets = []
var _cooldowns = {}


func _ready():
	connect("area_entered", self, "_on_area_entered")
	connect("body_entered", self, "_on_body_entered")


func configure(values = {}):
	if typeof(values) != TYPE_DICTIONARY:
		return self
	if "damage" in values:
		damage = float(values["damage"])
	if "type" in values:
		damage_type = str(values["type"])
	if "team" in values:
		team = str(values["team"])
	if "source" in values:
		source = values["source"]
	if "once" in values:
		once_per_target = bool(values["once"])
	if "cooldown" in values:
		hit_cooldown = float(values["cooldown"])
	if "knockback" in values:
		knockback = float(values["knockback"])
	return self


func _on_area_entered(area):
	_try_hit(area)


func _on_body_entered(body):
	_try_hit(body)


func _try_hit(collider):
	if not active or collider == null:
		return
	var target = _resolve_target(collider)
	if target == null or target == source:
		return
	if once_per_target and target in hit_targets:
		return
	if target in _cooldowns and _cooldowns[target] > 0.0:
		return
	hit_targets.append(target)
	if hit_cooldown > 0.0:
		_cooldowns[target] = hit_cooldown
	var info = {
		"amount": damage,
		"type": damage_type,
		"source": source,
		"position": global_position,
		"direction": (target.global_position - global_position).normalized() if target is Node2D else Vector2.ZERO,
		"knockback": knockback
	}
	if target.has_method("take_damage"):
		target.take_damage(info)
	elif target.has_method("receive_damage"):
		target.receive_damage(info)
	emit_signal("hit", target, info)


func _resolve_target(collider):
	if collider.has_method("take_damage"):
		return collider
	var parent = collider.get_parent()
	if parent != null and parent.has_method("take_damage"):
		return parent
	return null


func set_active(value):
	active = bool(value)
	monitoring = active


func reset_hits():
	hit_targets.clear()
	_cooldowns.clear()


func _process(delta):
	if _cooldowns.empty():
		return
	var remove = []
	for target in _cooldowns:
		_cooldowns[target] = max(0.0, _cooldowns[target] - delta)
		if _cooldowns[target] == 0.0:
			remove.append(target)
	for target in remove:
		_cooldowns.erase(target)
