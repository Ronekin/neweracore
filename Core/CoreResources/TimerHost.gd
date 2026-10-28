# TimerHost.gd — именованные таймеры с автоматической очисткой.
# Заменяет десятки Timer.new() и ручные disconnect через General.

extends Node

var timers = {}
var _serial = 0


func start(name, wait_time, target, method, args = [], one_shot = true):
	cancel(name)
	if wait_time <= 0.0:
		wait_time = 0.001
	if target == null or method == "":
		return null
	var timer = Timer.new()
	timer.name = "Timer_" + str(name)
	timer.wait_time = wait_time
	timer.one_shot = one_shot
	timer.autostart = false
	add_child(timer)
	timer.connect("timeout", self, "_on_timer_timeout", [name, target, method, args])
	timers[name] = {
		"timer": timer,
		"target": target,
		"method": method,
		"args": args,
		"one_shot": one_shot
	}
	timer.start()
	return timer


func start_once(name, wait_time, target, method, args = []):
	return start(name, wait_time, target, method, args, true)


func start_repeating(name, wait_time, target, method, args = []):
	return start(name, wait_time, target, method, args, false)


func after(wait_time, target, method, args = []):
	_serial += 1
	return start("_after_" + str(_serial), wait_time, target, method, args, true)


func _on_timer_timeout(name, target, method, args):
	var entry = timers.get(name, null)
	if entry != null and bool(entry.get("one_shot", true)):
		timers.erase(name)
		var timer = entry.get("timer", null)
		if timer != null and is_instance_valid(timer):
			timer.queue_free()
	if target != null and is_instance_valid(target) and target.has_method(method):
		target.callv(method, args)


func cancel(name):
	if not (name in timers):
		return false
	var entry = timers[name]
	timers.erase(name)
	var timer = entry.get("timer", null)
	if timer != null and is_instance_valid(timer):
		timer.stop()
		timer.queue_free()
	return true


func cancel_all():
	for name in timers.keys():
		cancel(name)


func has(name):
	if not (name in timers):
		return false
	var entry = timers[name]
	var timer = entry.get("timer", null)
	return timer != null and is_instance_valid(timer) and not timer.is_stopped()


func is_running(name):
	return has(name)


func remaining(name):
	if not (name in timers):
		return 0.0
	var timer = timers[name].get("timer", null)
	if timer == null or not is_instance_valid(timer):
		return 0.0
	return timer.time_left


func pause(name):
	if name in timers:
		var timer = timers[name].get("timer", null)
		if timer != null and is_instance_valid(timer):
			timer.paused = true


func resume(name):
	if name in timers:
		var timer = timers[name].get("timer", null)
		if timer != null and is_instance_valid(timer):
			timer.paused = false


func clear():
	cancel_all()
