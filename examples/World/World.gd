# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Spatial


func _on_add_orange_async_pressed() -> void:
	var r := 100.0
	var pos := Vector3(
		rand_range(-r, r),
		20.0,
		rand_range(-r, r)
	)

	var target = self.get_tree().get_current_scene()
	var scene_path := "res://examples/Items/Orange/Orange.tscn"
	AsyncLoader.instance(target, scene_path, pos, false, true)


func _on_add_orange_async_with_cb_pressed() -> void:
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
	var scene_path := "res://examples/Items/Orange/Orange.tscn"
	var cb := funcref(self, "_on_orange_loaded_cb")
	AsyncLoader.instance_with_cb(scene_path, cb, data, true)

func _on_orange_loaded_cb(instance : Node, data : Dictionary) -> void:
	#print(["_on_orange_loaded_cb", instance, data])
	var target = data["target"]
	var pos = data["pos"]
	#print(["_on_orange_loaded_cb", instance, target, pos])
	target.add_child(instance)
	instance.transform.origin = pos


func _on_add_orange_sync_pressed() -> void:
	var r := 100.0
	var pos := Vector3(
		rand_range(-r, r),
		20.0,
		rand_range(-r, r)
	)

	var target = self.get_tree().get_current_scene()
	var scene_path := "res://examples/Items/Orange/Orange.tscn"
	var orange = AsyncLoader.instance_sync(scene_path)
	target.add_child(orange)
	orange.transform.origin = pos



func _on_change_scene_pressed() -> void:
	AsyncLoader.change_scene("res://examples/World2/World2.tscn", "res://examples/Loading/Loading.tscn")


func _on_button_list_cached_pressed() -> void:
	for scene in AsyncLoader._scene_cache.get_all_cached_paths():
		print(scene)
