# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node


const GRAVITY := -40.0
const WORLD_TILES_WIDE := 4
const TILE_WIDTH := 200

var _is_ready_for_movement := false
var _world_offset := Vector3(0, 0, 0)
var _player = null
var _player_tile = null

var _fps_timer : Timer

func _ready() -> void:
	# Every 1 second show FPS in the title
	_fps_timer = Timer.new()
	self.add_child(_fps_timer)
	var err := _fps_timer.connect("timeout", self, "_on_fps_timeout")
	assert(err == OK)
	_fps_timer.set_wait_time(1.0)
	_fps_timer.set_one_shot(false)
	_fps_timer.start()
	self._on_fps_timeout()

# Set the title with DEBUG and FPS every 1 second
func _on_fps_timeout() -> void:
	var godot_debug = "DEBUG" if OS.is_debug_build() else "RELEASE"
	var fps = Engine.get_frames_per_second()
	var title = "(Godot: %s) | FPS: %s" % [godot_debug, fps]
	OS.set_window_title(title)

func _on_loading_started(total : int) -> void:
	print("called _on_loading_started: %s" % [total])

func _on_loading_progress(current : int, total : int) -> void:
	pass#print("called _on_loading_progress: %s of %s" % [current, total])

func _on_loading_done(total : int) -> void:
	print("called _on_loading_done: %s" % [total])

func _on_scene_changed(total : int) -> void:
	var scene = self.get_tree().current_scene
	print("called _on_scene_changed: %s, %s" % [scene.name, total])


func recursively_get_all_children_in_group(target : Node, group_name : String) -> Array:
	var matches := []
	var to_search := [target]
	while not to_search.empty():
		var entry = to_search.pop_front()

		for child in entry.get_children():
			to_search.append(child)

		if entry.is_in_group(group_name):
			matches.append(entry)

	return matches
