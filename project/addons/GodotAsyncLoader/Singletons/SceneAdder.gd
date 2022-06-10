# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/AsyncLoaderExample

extends Node

const sleep_time := 100
var _is_running := false
var _thread : Thread
var _to_add := []
var _to_add_mutex := Mutex.new()

var _to_adds := {
	"terrain" : [],
	"building" : [],
	"furniture" : [],
	"plant" : [],
	"item" : [],
	"npc" : [],
	"etc" : [],
}

func _enter_tree() -> void:
	_thread = Thread.new()
	var err = _thread.start(self, "_run_thread", 0, Thread.PRIORITY_LOW)
	assert(err == OK)

func _exit_tree() -> void:
	if _is_running:
		_is_running = false

	if _thread:
		_thread.wait_to_finish()
		_thread = null

func add_scene(on_done_cb : FuncRef, target : Node, path : String, pos : Vector3, is_pos_global : bool, cb : FuncRef, instance : Node, data : Dictionary, has_priority : bool) -> void:
	var entry := {
		"target" : target,
		"on_done_cb" : on_done_cb,
		"path" : path,
		"pos" : pos,
		"is_pos_global" : is_pos_global,
		"cb" : cb,
		"instance" : instance,
		"data" : data,
		"has_priority" : has_priority,
	}

	_to_add_mutex.lock()

	if has_priority:
		_to_add.push_front(entry)
	else:
		_to_add.push_back(entry)

	_to_add_mutex.unlock()

func _can_add(category : String) -> bool:
	match category:
		"terrain":
			return not _to_adds["terrain"].empty()
		"building":
			return not _to_adds["building"].empty() and not _can_add("terrain")
		"furniture":
			return not _to_adds["furniture"].empty() and not _can_add("building")
		"plant":
			return not _to_adds["plant"].empty() and not _can_add("furniture")
		"item":
			return not _to_adds["item"].empty() and not _can_add("plant")
		"npc":
			return not _to_adds["npc"].empty() and not _can_add("item")
		"etc":
			return not _to_adds["etc"].empty() and not _can_add("npc")

	return false

func _run_thread(_arg : int) -> void:
	_is_running = true
	var is_reset := false

	while _is_running:
		is_reset = false
		self._check_for_new_scenes()

		while _is_running and not is_reset and _can_add("terrain"):
			is_reset = _add_entry(_to_adds["terrain"], "Terrain")

		while _is_running and not is_reset and _can_add("building"):
			is_reset = _add_entry(_to_adds["building"], "Building")

		while _is_running and not is_reset and _can_add("furniture"):
			is_reset = _add_entry(_to_adds["furniture"], "Furniture")

		while _is_running and not is_reset and _can_add("plant"):
			is_reset = _add_entry(_to_adds["plant"], "Plant")

		while _is_running and not is_reset and _can_add("item"):
			is_reset = _add_entry(_to_adds["item"], "Item")

		while _is_running and not is_reset and _can_add("npc"):
			is_reset = _add_entry(_to_adds["npc"], "NPC")

		while _is_running and not is_reset and _can_add("etc"):
			is_reset = _add_entry(_to_adds["etc"], "ETC")

		OS.delay_msec(2)

func _add_entry(from : Array, category : String) -> bool:
	var entry = from.pop_front()
	if entry["is_child"]:
		_add_child(entry, category)
	else:
		_add_parent(entry, category)

	OS.delay_msec(sleep_time)
	return self._check_for_new_scenes()

func _add_child(entry, category : String) -> void:
	var parent = entry["parent"]
	var instance = entry["instance"]
	var transform = entry["transform"]
	instance.transform = transform
	self.call_deferred("_on_add_child_cb", parent, instance, category)

func _on_add_child_cb(parent : Node, instance : Node, category : String) -> void:
	var start := OS.get_ticks_msec()
	parent.add_child(instance)
	var time := OS.get_ticks_msec() - start
	print("+++ Adding %s \"%s\" %s ms" % [category, instance.name, time])

func _add_parent(entry, category : String) -> void:
	var target = entry["target"]
	var on_done_cb = entry["on_done_cb"]
	var path = entry["path"]
	var pos = entry["pos"]
	var is_pos_global = entry["is_pos_global"]
	var cb = entry["cb"]
	var instance = entry["instance"]
	var data = entry["data"]
	print("+++ Adding %s \"%s\"" % [category, instance.name])
	#on_done_cb.call_func(target, path, pos, is_pos_global, cb, instance, data)
	on_done_cb.call_deferred("call_func", target, path, pos, is_pos_global, cb, instance, data)

func _get_destination_queue_for_instance(instance : Node, has_priority : bool, default_queue = null):
	if has_priority:
		return _to_adds["terrain"]

	for group in instance.get_groups():
		match group:
			"terrain":
				return _to_adds["terrain"]
			"building":
				return _to_adds["building"]
			"furniture":
				return _to_adds["furniture"]
			"plant":
				return _to_adds["plant"]
			"item":
				return _to_adds["item"]
			"npc":
				return _to_adds["npc"]
			"etc":
				return _to_adds["etc"]

	return default_queue

func _check_for_new_scenes() -> bool:
	_to_add_mutex.lock()
	var to_add := _to_add.duplicate()
	_to_add.clear()
	_to_add_mutex.unlock()

	var has_new_scenes := false
	for entry in to_add:
		var target = entry["target"]
		var has_priority = entry["has_priority"]
		#OS.delay_msec(1)
		var instance = entry["instance"]

		# Get the queue for this instance type
		var to = _get_destination_queue_for_instance(instance, has_priority, _to_adds["terrain"])

		# Add the scene
		var entry_copy = entry.duplicate()
		#entry_copy["target"] = target
		entry_copy["is_child"] = false
		to.append(entry_copy)
		has_new_scenes = true

		# Remove all the scene's children to add later
		for child in _recursively_get_all_children_of_type(instance, Node):
			to = _get_destination_queue_for_instance(child, false, null)
			if to != null:
				var parent = child.get_parent()
				if parent != null:
					to.append({ "is_child" : true, "instance" : child, "parent" : parent, "transform" : child.transform})
					parent.remove_child(child)

	return has_new_scenes

func _recursively_get_all_children_of_type(target : Node, target_type) -> Array:
	var matches := []
	var to_search := [target]
	while not to_search.empty():
		var entry = to_search.pop_front()

		for child in entry.get_children():
			to_search.append(child)

		if entry is target_type:
			matches.append(entry)

	return matches
