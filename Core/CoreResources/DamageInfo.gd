# DamageInfo.gd — единый объект описания урона.
# Убирает разрозненные аргументы вида (amount_hp, amount_dist, block_destroy,
# direct_player_set, popadanie_check). Мод и ядро передают один объект.

extends Reference

var amount = 0.0
var type = "physical"
var source = null
var target = null
var position = Vector2.ZERO
var direction = Vector2.ZERO
var knockback = 0.0
var crit = false
var ignore_invuln = false
var ignore_block = false
var ignore_cooldown = false
var tags = []
var metadata = {}

var blocked = false
var applied = 0.0
var absorbed = 0.0
var killed = false


func _init(values = null):
	if typeof(values) == TYPE_DICTIONARY:
		apply(values)
	elif values != null:
		amount = float(values)


func apply(values):
	if typeof(values) != TYPE_DICTIONARY:
		return self
	amount = float(values.get("amount", amount))
	type = str(values.get("type", type))
	source = values.get("source", source)
	target = values.get("target", target)
	position = values.get("position", position)
	direction = values.get("direction", direction)
	knockback = float(values.get("knockback", knockback))
	crit = bool(values.get("crit", crit))
	ignore_invuln = bool(values.get("ignore_invuln", ignore_invuln))
	ignore_block = bool(values.get("ignore_block", ignore_block))
	ignore_cooldown = bool(values.get("ignore_cooldown", ignore_cooldown))
	if "tags" in values:
		tags = values["tags"].duplicate()
	if "metadata" in values:
		metadata = values["metadata"].duplicate(true)
	return self


func add_tag(tag):
	if not (tag in tags):
		tags.append(tag)
	return self


func has_tag(tag):
	return tag in tags


func copy():
	var info = get_script().new()
	info.amount = amount
	info.type = type
	info.source = source
	info.target = target
	info.position = position
	info.direction = direction
	info.knockback = knockback
	info.crit = crit
	info.ignore_invuln = ignore_invuln
	info.ignore_block = ignore_block
	info.ignore_cooldown = ignore_cooldown
	info.tags = tags.duplicate()
	info.metadata = metadata.duplicate(true)
	return info


func to_dict():
	return {
		"amount": amount,
		"type": type,
		"source": source,
		"target": target,
		"position": position,
		"direction": direction,
		"knockback": knockback,
		"crit": crit,
		"ignore_invuln": ignore_invuln,
		"ignore_block": ignore_block,
		"ignore_cooldown": ignore_cooldown,
		"tags": tags.duplicate(),
		"metadata": metadata.duplicate(true),
		"blocked": blocked,
		"applied": applied,
		"absorbed": absorbed,
		"killed": killed
	}
