# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _scenes := {}
var _scenes_mutex := Mutex.new()

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
