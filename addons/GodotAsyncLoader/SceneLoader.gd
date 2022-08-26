# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _is_running := false
var _thread : Thread
var _scenes := {}
var _scenes_mutex := Mutex.new()
var _to_load := []
var _to_load_mutex := Mutex.new()

func load_scene_async_with_cb(scene_path : String, cb : FuncRef, data := {}, has_priority := false) -> void:
	var entry := {
		"scene_path" : scene_path,
		"cb" : cb,
		"data" : data,
		"has_priority" : has_priority,
	}

	_to_load_mutex.lock()
	if has_priority:
		_to_load.push_front(entry)
	else:
		_to_load.push_back(entry)
	_to_load_mutex.unlock()
	#print(_to_load)

func load_scene_async(target : Node, scene_path : String, pos : Vector3, is_pos_global : bool, has_priority := false) -> void:
	var data := {
		"target" : target,
		"pos" : pos,
		"is_pos_global" : is_pos_global,
	}
	var cb := funcref(self, "_default_load_scene_async_cb")
	self.load_scene_async_with_cb(scene_path, cb, data, has_priority)

func _default_load_scene_async_cb(instance : Node, data : Dictionary) -> void:
	var target = data["target"]
	var pos = data["pos"]
	var is_pos_global = data["is_pos_global"]

	target.add_child(instance)

	# Set the instance position
	if pos != Vector3.INF and "transform" in instance:
		# Convert the position from global to local if needed
		if is_pos_global:
			pos = pos - target.global_transform.origin

		instance.transform.origin = pos


func load_scene_sync(target : Node, scene_path : String) -> Node:
	var data := {}

	# Load the scene
	var start := OS.get_ticks_msec()
	var scene = _get_cached_scene(scene_path)
	if scene == null: return null
	if AsyncLoader._is_logging_loads: data["load"] = OS.get_ticks_msec() - start

	# Instance the scene
	start = OS.get_ticks_msec()
	var instance = scene.instance()
	if AsyncLoader._is_logging_loads: data["instance"] = OS.get_ticks_msec() - start

	# Add the scene to the target
	start = OS.get_ticks_msec()
	if target:
		target.add_child(instance)
	if AsyncLoader._is_logging_loads: data["add"] = OS.get_ticks_msec() - start

	if AsyncLoader._is_logging_loads:
		print("!!!!!! SYNC scene %s\n    load %s ms in MAIN!!!!!!!!!!!!\n    instance %s ms in MAIN!!!!!!!!!!!!\n    add %s ms in MAIN!!!!!!!!!!!!" % [scene_path, data["load"], data["instance"], data["add"]])

	return instance

func _run_loader_thread(_arg : int) -> void:
	_is_running = true

	while _is_running:
		_to_load_mutex.lock()
		var to_load := _to_load.duplicate()
		_to_load.clear()
		_to_load_mutex.unlock()

		#print(to_load)
		for entry in to_load:
			var scene_path = entry["scene_path"]
			var cb = entry["cb"]
			var data = entry["data"]
			var has_priority = entry["has_priority"]
			#print("!!!!!!! scene_path: %s" % scene_path)

			var is_existing = ResourceLoader.exists(scene_path)
			#print(scene_path, " ", is_existing)
			if not is_existing:
				push_error("Scene files does not exist: %s" % [scene_path])
			else:
				# Load the scene
				var start := OS.get_ticks_msec()
				var scene = _get_cached_scene(scene_path)
				if AsyncLoader._is_logging_loads: data["load"] = OS.get_ticks_msec() - start

				# Instance the scene
				start = OS.get_ticks_msec()
				var instance = scene.instance()
				if AsyncLoader._is_logging_loads: data["instance"] = OS.get_ticks_msec() - start

				# Send the instance to the callback in the main thread
				AsyncLoader._add_scene(funcref(self, "_on_done"), scene_path, cb, instance, data, has_priority)
				#self.call_deferred("_on_done", target, scene_path, cb, instance, data)
				#print("??????? instance.global_transform.origin: %s" % instance.global_transform.origin)

		OS.delay_msec(2)

func _on_done(scene_path : String, cb : FuncRef, instance : Node, data : Dictionary) -> void:
#	var start := OS.get_ticks_msec()

#	# Just return if target is invalid
#	if not is_instance_valid(target):
#		return

	# Just return if instance is invalid
	if not is_instance_valid(instance):
		return

	# Just return if the cb is invalid
	if cb != null and not cb.is_valid():
		return

	if cb != null:
		#cb.call_deferred("call_func", instance, data)
		cb.call_func(instance, data)
	else:
		push_error("!!! Warning: cb was null!!!!")
#		# Set the instance position
#		if pos != Vector3.INF and "transform" in instance:
#			# Convert the position from global to local if needed
#			if is_pos_global:
#				pos = pos - target.global_transform.origin
#
#			instance.transform.origin = pos
#
#		# Add the instance to the target
#		target.add_child(instance)

#		if AsyncLoader._is_logging_loads: data["add"] = OS.get_ticks_msec() - start
#
#		if AsyncLoader._is_logging_loads:
#			var message := ""
#			message += "!!!!!! ASYNC scene %s\n" % scene_path
#			message += "    load %s ms in THREAD\n" % data["load"]
#			message += "    instance %s ms in THREAD\n" % data["instance"]
#			message += "    add %s ms in MAIN!!!!!!!!!!!!" % data["add"]
#			print(message)

func _get_cached_scene(scene_path : String) -> PackedScene:
	# Return null if path does not exist
	if not ResourceLoader.exists(scene_path):
		push_error("Scene files does not exist: %s" % [scene_path])
		return null

	# Check if the scene is loaded
	_scenes_mutex.lock()
	var has_scene := _scenes.has(scene_path)
	_scenes_mutex.unlock()

	# Load the scene if it isn't loaded
	if not has_scene:
		var packed_scene = ResourceLoader.load(scene_path)
		_scenes_mutex.lock()
		_scenes[scene_path] = packed_scene
		_scenes_mutex.unlock()

	# Get the scene
	_scenes_mutex.lock()
	var scene = _scenes[scene_path]
	_scenes_mutex.unlock()

	return scene
