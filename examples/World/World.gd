# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Spatial

func _on_add_orange_pressed() -> void:
	var r := 100.0
	var pos := Vector3(
		rand_range(-r, r),
		20.0,
		rand_range(-r, r)
	)

	var target = self.get_tree().get_current_scene()
	var path := "res://examples/Items/Orange/Orange.tscn"
	AsyncLoader.load_scene_async(target, path, pos, false)


func _on_add_orange_with_cb_pressed() -> void:
	var r := 100.0
	var pos := Vector3(
		rand_range(-r, r),
		20.0,
		rand_range(-r, r)
	)

	var data := {
		"target" : self.get_tree().get_current_scene(),
		"pos" : pos,
	}
	var scene_file := "res://examples/Items/Orange/Orange.tscn"
	var cb := funcref(self, "_on_orange_loaded_cb")
	AsyncLoader.load_scene_async_with_cb(scene_file, cb, data)

func _on_orange_loaded_cb(instance : Node, data : Dictionary) -> void:
	var target = data["target"]
	target.add_child(instance)
	instance.transform.origin = data["pos"]
