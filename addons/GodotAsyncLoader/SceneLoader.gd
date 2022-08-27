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


func load_and_instance_async_with_cb(scene_path : String, cb : FuncRef, data := {}, has_priority := false) -> void:
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
			var packed_scene = _get_cached_scene(scene_path)
			AsyncLoader._instance_scene(packed_scene, scene_path, cb, data, has_priority)

		OS.delay_msec(2)

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
