# Projectile.gd — базовый снаряд на KinematicBody2D.
# Конкретные пули/ножи/ногти мода наследуются и задают числа, сцены и VFX.

extends KinematicBody2D
class_name CoreProjectile

signal hit(target, info)
signal expired()

export var speed = 600.0
export var damage = 10.0
export var lifetime = 3.0
export var team = "neutral"
export var pierce = 0
export var destroy_on_hit = true
export var gravity_scale = 0.0
export var collision_mask = 1
export var damage_type = "physical"

var direction = Vector2.RIGHT
var alive = true
var source = null
var age = 0.0
var last_velocity = Vector2.ZERO
var hit_targets = []


func setup(values = {}):
	if typeof(values) != TYPE_DICTIONARY:
		return self
	if "position" in values:
		position = values["position"]
	if "direction" in values:
		direction = values["direction"].normalized()
	if "speed" in values:
		speed = float(values["speed"])
	if "damage" in values:
		damage = float(values["damage"])
	if "lifetime" in values:
		lifetime = float(values["lifetime"])
	if "team" in values:
		team = str(values["team"])
	if "source" in values:
		source = values["source"]
	if "pierce" in values:
		pierce = int(values["pierce"])
	if "destroy_on_hit" in values:
		destroy_on_hit = bool(values["destroy_on_hit"])
	return self


func _physics_process(delta):
	if not alive:
		return
	age += delta
	if lifetime > 0.0 and age >= lifetime:
		_expire()
		return
	var motion = direction * speed * delta
	if gravity_scale != 0.0:
		motion.y += 980.0 * gravity_scale * delta * delta
	var collision = move_and_collide(motion)
	if collision != null:
		_handle_collision(collision)


func _handle_collision(collision):
	var collider = collision.get("collider", null)
	if collider == null:
		_expire()
		return
	if collider == source:
		return
	var target = _resolve_target(collider)
	if target != null and not (target in hit_targets):
		hit_targets.append(target)
		var info = {
			"amount": damage,
			"type": damage_type,
			"source": source,
			"position": global_position,
			"direction": direction,
			"knockback": 0.0
		}
		_apply_damage(target, info)
		emit_signal("hit", target, info)
		if pierce > 0:
			pierce -= 1
		elif destroy_on_hit:
			_expire()
			return
	_expire()


func _resolve_target(collider):
	if collider.has_method("take_damage"):
		return collider
	if collider.has_method("get_parent") and collider.get_parent() != null and collider.get_parent().has_method("take_damage"):
		return collider.get_parent()
	if collider.has_method("receive_damage"):
		return collider
	return null


func _apply_damage(target, info):
	if target.has_method("take_damage"):
		target.take_damage(info)
	elif target.has_method("receive_damage"):
		target.receive_damage(info)


func _expire():
	if not alive:
		return
	alive = false
	emit_signal("expired")
	if is_inside_tree():
		queue_free()


func set_direction(value):
	direction = value.normalized()


func distance_travelled():
	return speed * age
