# Audio.gd — музыка и SFX New Era Core.
# Ядро умеет проигрывать ресурсы и управлять громкостью, но не знает, какая
# музыка должна играть на конкретной карте. Это решает мод.

extends Node

signal music_started(path)
signal music_stopped()
signal sfx_started(path, player)

var music_player = null
var sfx_players = []
var sfx_pool_size = 12
var master_volume = 1.0
var music_volume = 0.7
var sfx_volume = 1.0
var current_music_path = ""
var current_music_stream = null
var logger = null
var _fade_tween = null


func _ready():
	_ensure_players()


func set_logger(value):
	logger = value
	return self


func _ensure_players():
	if music_player == null:
		music_player = AudioStreamPlayer.new()
		music_player.name = "Music"
		var music_bus = AudioServer.get_bus_index("Music")
		if music_bus >= 0:
			music_player.bus = "Music"
		add_child(music_player)
	while sfx_players.size() < sfx_pool_size:
		var player = AudioStreamPlayer.new()
		player.name = "SFX_" + str(sfx_players.size())
		var sfx_bus = AudioServer.get_bus_index("SFX")
		if sfx_bus >= 0:
			player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)


func play_music(path_or_stream, loop = true, volume = 1.0, fade = 0.0):
	_ensure_players()
	var stream = _resolve_stream(path_or_stream)
	if stream == null:
		_log_warn("Music not found: " + str(path_or_stream))
		return false
	_apply_loop(stream, loop)
	current_music_stream = stream
	current_music_path = str(path_or_stream) if typeof(path_or_stream) == TYPE_STRING else ""
	music_player.stream = stream
	music_player.volume_db = _volume_to_db(volume * master_volume * music_volume)
	if fade > 0.0:
		music_player.volume_db = -80.0
		_fade_to(0.0, fade)
	music_player.play()
	emit_signal("music_started", current_music_path)
	return true


func play_music_stream(stream, loop = true, volume = 1.0):
	return play_music(stream, loop, volume)


func stop_music(fade = 0.0):
	_ensure_players()
	if fade > 0.0 and music_player.playing:
		_fade_to(-80.0, fade, "stop")
		return
	music_player.stop()
	current_music_stream = null
	current_music_path = ""
	emit_signal("music_stopped")


func pause_music():
	if music_player != null:
		music_player.stream_paused = true


func resume_music():
	if music_player != null:
		music_player.stream_paused = false


func is_music_playing():
	return music_player != null and music_player.playing


func get_music_position():
	return music_player.get_playback_position() if music_player != null else 0.0


func seek_music(position):
	if music_player != null:
		music_player.seek(position)


func play_sfx(path_or_stream, volume = 1.0, pitch = 1.0, bus = ""):
	_ensure_players()
	var stream = _resolve_stream(path_or_stream)
	if stream == null:
		_log_warn("SFX not found: " + str(path_or_stream))
		return null
	var player = _get_free_sfx_player()
	player.stream = stream
	player.volume_db = _volume_to_db(volume * master_volume * sfx_volume)
	player.pitch_scale = max(0.01, pitch)
	if bus != "" and AudioServer.get_bus_index(bus) >= 0:
		player.bus = bus
	player.play()
	emit_signal("sfx_started", str(path_or_stream), player)
	return player


func play_sfx_random(paths, volume = 1.0):
	if typeof(paths) != TYPE_ARRAY or paths.empty():
		return null
	return play_sfx(paths[randi() % paths.size()], volume)


func stop_all_sfx():
	_ensure_players()
	for player in sfx_players:
		player.stop()


func set_master_volume(value):
	master_volume = clamp(float(value), 0.0, 4.0)
	_apply_volumes()


func set_music_volume(value):
	music_volume = clamp(float(value), 0.0, 4.0)
	_apply_volumes()


func set_sfx_volume(value):
	sfx_volume = clamp(float(value), 0.0, 4.0)
	_apply_volumes()


func set_bus_volume(bus_name, linear_value):
	var index = AudioServer.get_bus_index(str(bus_name))
	if index >= 0:
		AudioServer.set_bus_volume_db(index, _volume_to_db(linear_value))


func set_bus_muted(bus_name, muted):
	var index = AudioServer.get_bus_index(str(bus_name))
	if index >= 0:
		AudioServer.set_bus_mute(index, bool(muted))


func _apply_volumes():
	if music_player != null:
		music_player.volume_db = _volume_to_db(master_volume * music_volume)
	for player in sfx_players:
		if not player.playing:
			player.volume_db = _volume_to_db(master_volume * sfx_volume)


func _resolve_stream(source):
	if source == null:
		return null
	if source is AudioStream:
		return source
	if typeof(source) == TYPE_STRING:
		if not ResourceLoader.exists(source):
			return null
		return load(source)
	return null


func _apply_loop(stream, loop):
	if stream is AudioStreamMP3:
		stream.loop = bool(loop)
	elif stream is AudioStreamOGGVorbis:
		stream.loop = bool(loop)
	elif stream is AudioStreamSample:
		stream.loop_mode = AudioStreamSample.LOOP_FORWARD if loop else AudioStreamSample.LOOP_DISABLED


func _get_free_sfx_player():
	for player in sfx_players:
		if not player.playing:
			return player
	return sfx_players[0]


func _volume_to_db(linear_value):
	var value = max(0.0001, float(linear_value))
	return linear2db(value)


func _fade_to(target_db, duration, action = ""):
	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.stop_all()
		_fade_tween.queue_free()
	_fade_tween = Tween.new()
	add_child(_fade_tween)
	_fade_tween.interpolate_property(music_player, "volume_db", music_player.volume_db, target_db, duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	if action == "stop":
		_fade_tween.connect("tween_all_completed", self, "_on_fade_stop_completed")
	_fade_tween.start()


func _on_fade_stop_completed():
	music_player.stop()
	current_music_stream = null
	current_music_path = ""
	emit_signal("music_stopped")


func _log_warn(message):
	if logger != null:
		logger.warn(message)
