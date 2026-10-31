# Hurtbox.gd — приёмник урона для сущности.
# Позволяет отделить визуальную/физическую зону от логики Entity.

extends Area2D
class_name CoreHurtbox

signal damaged(info)

export var damage_multiplier = 1.0
export var active = true
export var invulnerable = false

var entity = null
var last_info = null


func setup(target_entity, multiplier = 1.0):
	entity = target_entity
	damage_multiplier = float(multiplier)
	return self


func receive_damage(info):
	if not active or invulnerable:
		return null
	var data = info
	if typeof(info) == TYPE_DICTIONARY:
		data = info.duplicate()
		data["amount"] = float(data.get("amount", 0.0)) * damage_multiplier
	elif typeof(info) == TYPE_OBJECT:
		data = info.copy()
		data.amount *= damage_multiplier
	last_info = data
	emit_signal("damaged", data)
	if entity != null and entity.has_method("take_damage"):
		return entity.take_damage(data)
	return null


func set_active(value):
	active = bool(value)
	monitoring = active
	monitorable = active


func set_invulnerable(value):
	invulnerable = bool(value)
