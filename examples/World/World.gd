# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Spatial

func _on_add_orange_pressed() -> void:
	var r := 100.0
	var pos := Vector3(rand_range(-r, r), 20.0, rand_range(-r, r))

	var target = self.get_tree().get_current_scene()
	var scene_file := "res://examples/Items/Orange/Orange.tscn"
	AsyncLoader.load_scene_async(target, scene_file, pos, true)
