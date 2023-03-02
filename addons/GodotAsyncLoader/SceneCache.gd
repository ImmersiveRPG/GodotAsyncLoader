# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _cached := {}
var _cached_mutex := Mutex.new()

func _load_and_cache(scene_path : String) -> PackedScene:
	# Make sure the scene exists
	if not ResourceLoader.exists(scene_path):
		push_error("Scene files does not exist: %s" % [scene_path])
		return null

	# Load the scene
	# NOTE: ResourceLoader.load caches the scene after the first load
	ResourceLoader.load(scene_path)

	self._update_cache_list()

	var packed_scene = ResourceLoader.load(scene_path)
	return packed_scene

func _is_cached(scene_path : String) -> bool:
	var is_cached = false

	self._update_cache_list()

	_cached_mutex.lock()
	is_cached = _cached.has(scene_path)
	_cached_mutex.unlock()

	return is_cached

func _get_all_cached_paths() -> Array:
	var cached := []

	self._update_cache_list()

	_cached_mutex.lock()
	cached = _cached.keys()
	_cached_mutex.unlock()

	cached.sort()
	return cached

func _update_cache_list() -> void:
	# Cache the scenes that are not already cached
	var paths := ["res://"]
	while not paths.is_empty():
		var path : String = paths.pop_front()
		#print("path: %s" % [path])
		for entry in Helpers.DirectoryIterator.new(path, true, true):
			var full_path : String = path + entry.name

			if entry.is_dir:
				#print("    dir: %s" % [entry.name])
				paths.append(full_path + '/')
			else:
				#print("    file: %s" % [entry.name])
				if full_path.get_extension() == "tscn":
					_cached_mutex.lock()
					var is_cached := _cached.has(full_path)
					_cached_mutex.unlock()

					if not is_cached and ResourceLoader.has_cached(full_path):
						_cached_mutex.lock()
						_cached[full_path] = ResourceLoader.load(full_path)
						_cached_mutex.unlock()
						#print("Added to cache: %s" % [full_path])
