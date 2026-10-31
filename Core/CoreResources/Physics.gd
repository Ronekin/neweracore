# Physics.gd — общие физические операции New Era Core.
# Сервис живёт в дереве, чтобы получать актуальный world_2d. Контент и
# конкретные коллизионные слои задаёт мод.

extends Node

var gravity = Vector2(0, 980)
var target_fps = 60
var pixel_snap = true
var debug_collisions = false
var logger = null


func _ready():
	gravity = get_gravity()
	set_target_fps(target_fps)


func set_logger(value):
	logger = value
	return self


func get_space_state():
	if get_tree() == null:
		return null
	var root = get_tree().get_root()
	if root == null:
		return null
	var world = root.get_world_2d()
	if world == null:
		return null
	return world.direct_space_state


func set_gravity(gravity_vector):
	gravity = gravity_vector
	ProjectSettings.set_setting("physics/2d/default_gravity", abs(float(gravity.y)))
	var direction = gravity.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(0, 1)
	ProjectSettings.set_setting("physics/2d/default_gravity_vector", direction)
	return gravity


func get_gravity():
	var magnitude = 980.0
	if ProjectSettings.has_setting("physics/2d/default_gravity"):
		magnitude = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	var direction = Vector2(0, 1)
	if ProjectSettings.has_setting("physics/2d/default_gravity_vector"):
		direction = ProjectSettings.get_setting("physics/2d/default_gravity_vector")
	gravity = direction * magnitude
	return gravity


func set_target_fps(fps):
	target_fps = max(1, int(fps))
	Engine.target_fps = target_fps


func get_target_fps():
	return target_fps


func set_pixel_snap(enabled):
	pixel_snap = bool(enabled)
	ProjectSettings.set_setting("2d/snapping/use_gpu_pixel_snap", pixel_snap)


func is_pixel_snap():
	return pixel_snap


func set_debug_collisions(enabled):
	debug_collisions = bool(enabled)
	if get_tree() != null:
		get_tree().debug_collisions_hint = debug_collisions


func set_debug_physics(enabled):
	set_debug_collisions(enabled)


func raycast(from_pos, to_pos, collision_mask = 1, exclude = [], collide_with_bodies = true, collide_with_areas = false):
	var result = {
		"hit": false,
		"position": to_pos,
		"normal": Vector2.ZERO,
		"collider": null,
		"collider_id": 0,
		"shape": 0,
		"metadata": {}
	}
	var space = get_space_state()
	if space == null:
		return result
	var hit = space.intersect_ray(from_pos, to_pos, exclude, int(collision_mask), collide_with_bodies, collide_with_areas)
	if typeof(hit) == TYPE_DICTIONARY and not hit.empty():
		result["hit"] = true
		for key in hit:
			result[key] = hit[key]
	return result


func line_of_sight(from_pos, to_pos, collision_mask = 1, exclude = []):
	var result = raycast(from_pos, to_pos, collision_mask, exclude)
	return not result.get("hit", false)


func intersect_point(point, collision_mask = 1, exclude = [], collide_with_bodies = true, collide_with_areas = false):
	var space = get_space_state()
	if space == null:
		return []
	return space.intersect_point(point, 32, exclude, int(collision_mask), collide_with_bodies, collide_with_areas)


func intersect_shape(shape, transform, collision_mask = 1, exclude = [], collide_with_bodies = true, collide_with_areas = false):
	var space = get_space_state()
	if space == null or shape == null:
		return []
	return space.intersect_shape(shape, transform, 32, exclude, int(collision_mask), collide_with_bodies, collide_with_areas)


func overlap_circle(center, radius, collision_mask = 1, exclude = [], collide_with_bodies = true, collide_with_areas = false):
	var shape = CircleShape2D.new()
	shape.radius = radius
	return intersect_shape(shape, Transform2D(0, center), collision_mask, exclude, collide_with_bodies, collide_with_areas)


func overlap_rect(rect, collision_mask = 1, exclude = [], collide_with_bodies = true, collide_with_areas = false):
	var shape = RectangleShape2D.new()
	shape.extents = rect.size * 0.5
	return intersect_shape(shape, Transform2D(0, rect.position + rect.size * 0.5), collision_mask, exclude, collide_with_bodies, collide_with_areas)


func point_in_rect(position, rect):
	return rect.has_point(position)


func point_in_area(position, area_rect, _layer = "default"):
	return point_in_rect(position, area_rect)


func get_settings():
	return {
		"gravity": get_gravity(),
		"target_fps": target_fps,
		"pixel_snap": pixel_snap,
		"debug_collisions": debug_collisions
	}
