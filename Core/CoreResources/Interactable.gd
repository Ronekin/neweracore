# Interactable.gd — общая зона взаимодействия (NPC, сундук, дверь, предмет).
# Контент и текст подсказки задаёт мод.

extends Area2D
class_name CoreInteractable

signal interaction_available(actor)
signal interaction_unavailable(actor)
signal interacted(actor)

export var enabled = true
export var prompt = ""
export var one_shot = false
export var required_tag = ""

var used = false
var current_actor = null
var interaction_data = {}


func _ready():
	connect("body_entered", self, "_on_body_entered")
	connect("body_exited", self, "_on_body_exited")


func _on_body_entered(body):
	if not _can_interact(body):
		return
	current_actor = body
	emit_signal("interaction_available", body)


func _on_body_exited(body):
	if current_actor == body:
		current_actor = null
		emit_signal("interaction_unavailable", body)


func _can_interact(actor):
	if not enabled or used and one_shot or actor == null:
		return false
	if required_tag != "":
		if not actor.has_method("has_tag") or not actor.has_tag(required_tag):
			return false
	return true


func interact(actor = null):
	var target = actor if actor != null else current_actor
	if not _can_interact(target):
		return false
	used = true
	emit_signal("interacted", target)
	return true


func set_enabled(value):
	enabled = bool(value)
	monitoring = enabled
	monitorable = enabled


func reset():
	used = false
	current_actor = null
