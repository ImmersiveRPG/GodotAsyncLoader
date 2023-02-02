# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _is_running := false
var _thread : Thread
var _to_add := []
var _to_add_mutex := Mutex.new()
var _to_adds := {}

var GROUPS := []

func _set_groups(groups : Array) -> void:
	GROUPS = groups

	for group in GROUPS:
		_to_adds[group] = []

func _add_scene(instance : Node, added_cb : FuncRef, data : Dictionary, has_priority : bool) -> void:
	var entry := {
		"added_cb" : added_cb,
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

func _can_add(group : String) -> bool:
	var i := GROUPS.find(group)

	match i:
		# Return false if unknown group
		-1:
			return false
		# Return true if there are any instances of this group to add
		0:
			return not _to_adds[group].empty()
		# Return true if there are any instances of this group to add
		# and the previous group has no more instances to add
		_:
			var prev_group = GROUPS[i - 1]
			return not _to_adds[group].empty() and not _can_add(prev_group)

	return false

func _run_adder_thread(_arg : int) -> void:
	var config = get_node("/root/AsyncLoaderConfig")
	_is_running = true
	var is_reset := false

	while _is_running:
		is_reset = false
		self._check_for_new_scenes()

		for group in GROUPS:
			while _is_running and not is_reset and _can_add(group):
				is_reset = _add_entry(_to_adds[group], group)

		OS.delay_msec(config._thread_sleep_msec)

func _add_entry(from : Array, group : String) -> bool:
	var config = get_node("/root/AsyncLoaderConfig")
	var entry = from.pop_front()
	if entry["is_child"]:
		_add_entry_child(entry, group)
	else:
		_add_entry_parent(entry, group)

	OS.delay_msec(config._post_add_sleep_msec)
	return self._check_for_new_scenes()

func _add_entry_parent(entry, group : String) -> void:
	var added_cb = entry["added_cb"]
	var instance = entry["instance"]
	var data = entry["data"]
	#print(["!!! _add_entry_parent", instance, data])
	#added_cb.call_deferred("call_func", instance, data)
	Helpers.call_deferred_and_return_yielded(added_cb, "call_func", [instance, data])

func _add_entry_child(entry, group : String) -> void:
	var parent = entry["parent"]
	var owner = entry.get("owner", null)
	var instance = entry["instance"]
	var transform = entry["transform"]
	instance.transform = transform
	#self.call_deferred("_on_add_entry_child_cb", parent, owner, instance, group)
	Helpers.call_deferred_and_return_yielded(self, "_on_add_entry_child_cb", [parent, owner, instance, group])

func _on_add_entry_child_cb(parent : Node, owner : Node, instance : Node, group : String) -> void:
	parent.add_child(instance)
	if owner:
		instance.set_owner(owner)

func _get_destination_queue_for_instance(instance : Node, has_priority : bool, default_queue = null):
	if has_priority:
		return _to_adds[GROUPS[0]]

	for group in instance.get_groups():
		var i := GROUPS.find(group)
		if i != -1:
			return _to_adds[GROUPS[i]]

	return default_queue

func _check_for_new_scenes() -> bool:
	_to_add_mutex.lock()
	var to_add := _to_add.duplicate()
	_to_add.clear()
	_to_add_mutex.unlock()

	var has_new_scenes := false
	for entry in to_add:
		var has_priority = entry["has_priority"]
		var instance = entry["instance"]

		# Get the queue for this instance type
		var to = _get_destination_queue_for_instance(instance, has_priority, _to_adds[GROUPS[0]])

		# Add the scene
		var entry_copy = entry.duplicate()
		entry_copy["is_child"] = false
		to.append(entry_copy)
		has_new_scenes = true

		# Remove all the scene's children to add later
		for child in _recursively_get_all_children_of_type(instance, Node):
			to = _get_destination_queue_for_instance(child, false, null)
			if to != null:
				var parent = child.get_parent()
				var owner = instance
				if parent != null:
					to.append({ "is_child" : true, "instance" : child, "parent" : parent, "owner" : owner, "transform" : child.transform })
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
