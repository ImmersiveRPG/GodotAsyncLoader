# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _is_running := false
var _thread : Thread
var _to_instance := []
var _to_instance_mutex := Mutex.new()


func instance_with_cb(packed_scene : PackedScene, instanced_cb : FuncRef, data := {}, has_priority := false) -> void:
	var entry := {
		"packed_scene" : packed_scene,
		#"scene_path" : scene_path,
		"instanced_cb" : instanced_cb,
		"data" : data,
		#"has_priority" : has_priority,
	}

	_to_instance_mutex.lock()
	if has_priority:
		_to_instance.push_front(entry)
	else:
		_to_instance.push_back(entry)
	_to_instance_mutex.unlock()
	#print(_to_instance)

func _run_instancer_thread(_arg : int) -> void:
	_is_running = true

	while _is_running:
		_to_instance_mutex.lock()
		var to_instance := _to_instance.duplicate()
		_to_instance.clear()
		_to_instance_mutex.unlock()

		#print(to_instance)
		for entry in to_instance:
			var packed_scene = entry["packed_scene"]
			#var scene_path = entry["scene_path"]
			var instanced_cb = entry["instanced_cb"]
			var data = entry["data"]
			#var has_priority = entry["has_priority"]
			#print("!!!!!!! scene_path: %s" % scene_path)

			# Instance the scene
			var instance = packed_scene.instance()

			# Send the instance to the callback in the main thread
			#AsyncLoader._add_scene(funcref(self, "_on_done"), scene_path, cb, instance, data, has_priority)
			instanced_cb.call_deferred("call_func", instance, data)
			#self.call_deferred("_on_done", target, scene_path, cb, instance, data)
			#print("??????? instance.global_transform.origin: %s" % instance.global_transform.origin)

		OS.delay_msec(2)


