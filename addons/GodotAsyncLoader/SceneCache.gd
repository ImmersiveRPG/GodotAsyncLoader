# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _cached := {}
var _cached_mutex := Mutex.new()

func _get_cached(scene_path : String) -> PackedScene:
	# Return null if path does not exist
	if not ResourceLoader.exists(scene_path):
		push_error("Scene files does not exist: %s" % [scene_path])
		return null

	# Get loaded scene
	var packed_scene = ResourceLoader.load(scene_path)

	# Cache the scene if not already cached
	_cached_mutex.lock()
	if not _cached.has(scene_path):
		_cached[scene_path] = packed_scene
	_cached_mutex.unlock()

	return packed_scene

func _get_all_cached() -> Array:
	_cached_mutex.lock()
	var paths = _cached.keys()
	_cached_mutex.unlock()
	return paths

func _is_cached(scene_path : String) -> bool:
	_cached_mutex.lock()
	var is_cached := _cached.has(scene_path)
	_cached_mutex.unlock()
	return is_cached

func _uncache(scene_path : String) -> void:
	_cached_mutex.lock()
	_cached.erase(scene_path)
	_cached_mutex.unlock()
