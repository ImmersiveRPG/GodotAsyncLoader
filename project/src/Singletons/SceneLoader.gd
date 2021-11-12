# Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/AsyncLoaderExample

extends Node

var _is_logging_loads := false
var _is_running := false
var _thread : Thread
var _scenes := {}
var _scenes_mutex := Mutex.new()
var _to_load := {}
var _to_load_mutex := Mutex.new()

func _enter_tree() -> void:
	_thread = Thread.new()
	var err = _thread.start(self, "_run_thread", 0, Thread.PRIORITY_LOW)
	assert(err == OK)

func _exit_tree() -> void:
	if _is_running:
		_is_running = false

	if _thread:
		_thread.wait_to_finish()
		_thread = null

func load_scene_async_with_cb(target : Node, path : String, pos : Vector3, is_pos_global : bool, cb : FuncRef, logs : Dictionary, has_priority := false) -> void:
	_to_load_mutex.lock()
	if not _to_load.has(target):
		_to_load[target] = []
	var entry := {
		"path" : path,
		"cb" : cb,
		"pos" : pos,
		"is_pos_global" : is_pos_global,
		"logs" : logs,
		"has_priority" : has_priority,
	}
	if has_priority:
		_to_load[target].push_front(entry)
	else:
		_to_load[target].push_back(entry)
	_to_load_mutex.unlock()
	#print(_to_load)

func load_scene_async(target : Node, path : String, pos : Vector3, is_pos_global : bool) -> void:
	self.load_scene_async_with_cb(target, path, pos, is_pos_global, null, {})

func load_scene_sync(target : Node, path : String) -> Node:
	var logs := {}

	# Load the scene
	var start := OS.get_ticks_msec()
	var scene = _get_cached_scene(path)
	if scene == null: return null
	if SceneLoader._is_logging_loads: logs["load"] = OS.get_ticks_msec() - start

	# Instance the scene
	start = OS.get_ticks_msec()
	var instance = scene.instance()
	if SceneLoader._is_logging_loads: logs["instance"] = OS.get_ticks_msec() - start

	# Add the scene to the target
	start = OS.get_ticks_msec()
	if target:
		target.add_child(instance)
	if SceneLoader._is_logging_loads: logs["add"] = OS.get_ticks_msec() - start

	if SceneLoader._is_logging_loads:
		print("!!!!!! SYNC scene %s\n    load %s ms in MAIN!!!!!!!!!!!!\n    instance %s ms in MAIN!!!!!!!!!!!!\n    add %s ms in MAIN!!!!!!!!!!!!" % [path, logs["load"], logs["instance"], logs["add"]])

	return instance

func _run_thread(_arg : int) -> void:
	_is_running = true

	while _is_running:
		_to_load_mutex.lock()
		var to_load := _to_load.duplicate()
		_to_load = {}
		_to_load_mutex.unlock()

		for target in to_load:
			for entry in to_load[target]:
				var path = entry["path"]
				var cb = entry["cb"]
				var pos = entry["pos"]
				var is_pos_global = entry["is_pos_global"]
				var logs = entry["logs"]
				var has_priority = entry["has_priority"]
				#print("!!!!!!! path: %s" % path)

				var is_existing = ResourceLoader.exists(path)
				#print(path, " ", is_existing)
				if not is_existing:
					push_error("Scene files does not exist: %s" % [path])
				else:
					# Load the scene
					var start := OS.get_ticks_msec()
					var scene = _get_cached_scene(path)
					if SceneLoader._is_logging_loads: logs["load"] = OS.get_ticks_msec() - start

					# Instance the scene
					start = OS.get_ticks_msec()
					var instance = scene.instance()
					if SceneLoader._is_logging_loads: logs["instance"] = OS.get_ticks_msec() - start

					# Send the instance to the callback in the main thread
					SceneAdder.add_scene(funcref(self, "_on_done"), target, path, pos, is_pos_global, cb, instance, logs, has_priority)
					#self.call_deferred("_on_done", target, path, pos, is_pos_global, cb, instance, logs)
					#print("??????? instance.global_transform.origin: %s" % instance.global_transform.origin)

		OS.delay_msec(2)

func _on_done(target : Node, path : String, pos : Vector3, is_pos_global : bool, cb : FuncRef, instance : Node, logs : Dictionary) -> void:
	var start := OS.get_ticks_msec()
	if cb != null:
		#cb.call_deferred("call_func", path, instance, pos, is_pos_global, logs)
		cb.call_func(path, instance, pos, is_pos_global, logs)
	else:
		# Set the instance position
		if pos != Vector3.INF:
			# Convert the position from global to local if needed
			if is_pos_global:
				pos = pos - target.global_transform.origin

			instance.transform.origin = pos

		# Add the instance to the target
		target.add_child(instance)

		if SceneLoader._is_logging_loads: logs["add"] = OS.get_ticks_msec() - start

		if SceneLoader._is_logging_loads:
			var message := ""
			message += "!!!!!! ASYNC scene %s\n" % path
			message += "    load %s ms in THREAD\n" % logs["load"]
			message += "    instance %s ms in THREAD\n" % logs["instance"]
			message += "    add %s ms in MAIN!!!!!!!!!!!!" % logs["add"]
			print(message)

func _get_cached_scene(path : String) -> PackedScene:
	# Return null if path does not exist
	if not ResourceLoader.exists(path):
		push_error("Scene files does not exist: %s" % [path])
		return null

	# Check if the scene is loaded
	_scenes_mutex.lock()
	var has_scene := _scenes.has(path)
	_scenes_mutex.unlock()

	# Load the scene if it isn't loaded
	if not has_scene:
		var packed_scene = ResourceLoader.load(path)
		_scenes_mutex.lock()
		_scenes[path] = packed_scene
		_scenes_mutex.unlock()

	# Get the scene
	_scenes_mutex.lock()
	var scene = _scenes[path]
	_scenes_mutex.unlock()

	return scene

