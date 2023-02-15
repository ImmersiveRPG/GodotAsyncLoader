# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node


const GRAVITY := -40.0

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
