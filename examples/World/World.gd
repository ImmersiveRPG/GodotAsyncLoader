# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
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
	AsyncLoader.instance_async(target, scene_path, pos, false, true)


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
	AsyncLoader.instance_async_with_cb(scene_path, cb, data, true)

func _on_orange_loaded_cb(instance : Node, data : Dictionary) -> void:
	var target = data["target"]
	target.add_child(instance)
	instance.transform.origin = data["pos"]


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

func _on_list_cached_scenes_pressed() -> void:
	print("Cached scenes:")
	for scene_path in AsyncLoader.get_all_cached_scene_paths():
		print(scene_path)

func _on_is_orange_cached_pressed() -> void:
	var scene_path := "res://examples/Items/Orange/Orange.tscn"
	var is_cached = AsyncLoader.is_scene_cached(scene_path)
	print("Orange is cached: %s" % [is_cached])

func _on_un_cache_orange_pressed() -> void:
	var scene_path := "res://examples/Items/Orange/Orange.tscn"
	AsyncLoader.uncache_scene(scene_path)
	print("Orange scene uncached")

