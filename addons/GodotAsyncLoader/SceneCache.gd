# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _cached := {}
var _cached_mutex := Mutex.new()

func _set_cached(scene_path : String, packed_scene : PackedScene) -> void:
	_cached_mutex.lock()
	if not _cached.has(scene_path):
		_cached[scene_path] = packed_scene
	_cached_mutex.unlock()
