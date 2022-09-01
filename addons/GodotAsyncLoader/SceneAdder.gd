# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _is_running := false
var _thread : Thread
var _to_add := []
var _to_add_mutex := Mutex.new()
var _to_adds := {}

var GROUPS := ["default"]
var CANT_SLEEP_GROUPS := []

func _set_groups(groups : Array, cant_sleep_groups : Array) -> void:
	GROUPS = groups
	CANT_SLEEP_GROUPS = cant_sleep_groups

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
	if entry.has("owner"):
		_add_sleeping(entry)
	elif entry["is_child"]:
		_add_entry_child(entry, group)
	else:
		_add_entry_parent(entry, group)

	OS.delay_msec(config._post_add_sleep_msec)
	return self._check_for_new_scenes()

func _add_sleeping(entry) -> void:
	var node_owner = entry["owner"]
	var parent = entry["parent"]
	var instance = entry["instance"]
	self.call_deferred("_on_add_sleeping_cb", node_owner, parent, instance)

# FIXME: Move this into AsyncLoader and have it passed in as a callback
func _on_add_sleeping_cb(owner : Node, parent : Node, instance : Node) -> void:
	#print("@@@ owner.name: %s" % [owner.name])
	if not Global._sleeping_nodes.has(owner.name):
		Global._sleeping_nodes[owner.name] = []

	Global._sleeping_nodes[owner.name].push_front({
		"node_parent" : parent,
		"node" : instance
	})

func _add_entry_parent(entry, group : String) -> void:
	var added_cb = entry["added_cb"]
	var instance = entry["instance"]
	var data = entry["data"]
	#print(["!!! _add_entry_parent", instance, data])
	# FIXME: Should this use call_deferred?
	#added_cb.call_deferred("call_func", instance, data)
	added_cb.call_func(instance, data)

func _add_entry_child(entry, group : String) -> void:
	var parent = entry["parent"]
	var owner = entry.get("owner", null)
	var instance = entry["instance"]
	var transform = entry["transform"]
	instance.transform = transform
	self.call_deferred("_on_add_entry_child_cb", parent, owner, instance, group)

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
		var is_terrain = instance.get_groups().has(GROUPS[0])
		var is_first = entry["data"]["data"].get("is_first", false)
		#print("???? entry: %s" % [entry["data"]["data"]])

		# Get the queue for this instance type
		var to = _get_destination_queue_for_instance(instance, has_priority, _to_adds[GROUPS[0]])

		# Add the scene
		var entry_copy = entry.duplicate()
		entry_copy["is_child"] = false
		to.append(entry_copy)
		has_new_scenes = true

		# Remove all the scene's children to add later
		for child in recursively_get_all_children_of_type(instance, Node):
			to = _get_destination_queue_for_instance(child, false, null)
			if to != null:
				var parent = child.get_parent()
				var owner = instance
				if parent != null:
					parent.remove_child(child)
					var data := { "is_child" : true, "instance" : child, "parent" : parent, "transform" : child.transform }

					# Don't allow this child to sleep if in group
					var cant_sleep := false
					var groups = child.get_groups()
					for g in CANT_SLEEP_GROUPS:
						if groups.has(g):
							cant_sleep = true
							break

					if is_terrain and not cant_sleep and not is_first:
						data["owner"] = instance
					to.append(data)

	return has_new_scenes

func recursively_get_all_children_of_type(target : Node, target_type) -> Array:
	var matches := []
	var to_search := [target]
	while not to_search.empty():
		var entry = to_search.pop_front()

		for child in entry.get_children():
			to_search.append(child)

		if entry is target_type:
			matches.append(entry)

	return matches
