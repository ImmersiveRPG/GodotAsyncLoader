# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _is_running := false
var _thread : Thread
var _to_add := []
var _to_add_mutex := Mutex.new()
var _to_adds := {}

var GROUP_SLEEP_DISTANCES := []

func get_group_names() -> Array:
	var group_names := []
	for item in GROUP_SLEEP_DISTANCES:
		group_names.append(item["name"])
	return group_names

func set_groups(group_sleep_distances : Array) -> void:
	GROUP_SLEEP_DISTANCES = group_sleep_distances

	var GROUPS : Array = self.get_group_names()
	for group in GROUPS:
		_to_adds[group] = []

func add_scene(instance : Node, added_cb : FuncRef, data : Dictionary, has_priority : bool, is_sleeping_children : bool) -> void:
	var entry := {
		"added_cb" : added_cb,
		"instance" : instance,
		"data" : data,
		"has_priority" : has_priority,
		"is_sleeping_children" : is_sleeping_children,
	}

	_to_add_mutex.lock()
	if has_priority:
		_to_add.push_front(entry)
	else:
		_to_add.push_back(entry)
	_to_add_mutex.unlock()

func _can_add(group : String) -> bool:
	var GROUPS : Array = self.get_group_names()
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

func _get_queue_count() -> int:
	var GROUPS : Array = self.get_group_names()
	var count := 0
	for group in GROUPS:
		count += _to_adds[group].size()
	return count

func _run_adder_thread(_arg : int) -> void:
	var config = get_node("/root/AsyncLoaderConfig")
	_is_running = true
	var is_reset := false

	var GROUPS : Array = self.get_group_names()
	while _is_running:
		is_reset = false
		self._check_for_new_scenes()

		# Check for loading started event
		var is_started := false
		if AsyncLoader._was_queue_empty and _get_queue_count() > 0:
			is_started = true
			AsyncLoader._was_queue_empty = false

		var cb := funcref(AsyncLoader, "emit_signal")
		for group in GROUPS:
			while _is_running and not is_reset and _can_add(group):
				var count := _get_queue_count()
				is_reset = _add_entry(_to_adds[group], group)
				if is_started:
					AsyncLoader.call_throttled(cb, ["loading_started", AsyncLoader._total_queue_count])
					is_started = false
				AsyncLoader.call_throttled(cb, ["loading_progress", count, AsyncLoader._total_queue_count])

				# Check for loading done event
				if _get_queue_count() == 0:
					AsyncLoader.call_throttled(cb, ["loading_done", AsyncLoader._total_queue_count])
					AsyncLoader._total_queue_count = 0
					AsyncLoader._was_queue_empty = true

		OS.delay_msec(config._thread_sleep_msec)

func _add_entry(from : Array, group : String) -> bool:
	var config = get_node("/root/AsyncLoaderConfig")
	var entry = from.pop_front()
	#print([entry["instance"], entry.get("has_priority", null)])
	# FIXME: Move all sleep code into SceneSleeper
	if entry.get("is_sleeping", false):
		#_add_sleeping(entry)
		var node = entry["instance"]
		var node_parent = entry["parent"]
		var node_owner = entry["owner"]
		AsyncLoader.sleep_scene_child(node, node_parent, node_owner)
	elif entry["is_child"]:
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
	AsyncLoader.call_throttled(added_cb, [instance, data])

func _add_entry_child(entry, group : String) -> void:
	var parent = entry["parent"]
	var owner = entry.get("owner", null)
	var instance = entry["instance"]
	var transform = entry["transform"]
	instance.transform = transform

	var cb := funcref(self, "_on_add_entry_child_cb")
	AsyncLoader.call_throttled(cb, [parent, owner, instance, group])

func _on_add_entry_child_cb(parent : Node, owner : Node, instance : Node, group : String) -> void:
	# Make sure there is a parent, and it is valid
	if parent == null or not is_instance_valid(parent):
		push_error("!!! Warning: parent is not valid!!!!")
		return

	# If there is an owner, make sure it is valid
	if owner != null and not is_instance_valid(owner):
		push_error("!!! Warning: owner is not valid!!!!")
		return

	parent.add_child(instance)
	if owner:
		instance.set_owner(owner)
	print("! adding %s" % [instance])
	#yield(instance, "ready")

func _get_destination_queue_for_instance(instance : Node, has_priority : bool, default_queue = null):
	var GROUPS : Array = self.get_group_names()
	if has_priority:
		return _to_adds[GROUPS[0]]

	for group in instance.get_groups():
		var i := GROUPS.find(group)
		if i != -1:
			return _to_adds[GROUPS[i]]

	return default_queue

func _check_for_new_scenes() -> bool:
	var GROUPS : Array = self.get_group_names()

	_to_add_mutex.lock()
	var to_add := _to_add.duplicate()
	_to_add.clear()
	_to_add_mutex.unlock()

	var has_new_scenes := false
	for entry in to_add:
		var has_priority = entry["has_priority"]
		var instance = entry["instance"]
		var is_sleeping_children = entry["is_sleeping_children"]

		# Get the queue for this instance type
		var to = _get_destination_queue_for_instance(instance, has_priority, _to_adds[GROUPS[0]])

		# Add the scene
		var entry_copy = entry.duplicate()
		entry_copy["is_child"] = false
		to.append(entry_copy)
		AsyncLoader._total_queue_count += 1
		has_new_scenes = true

		# Remove all the scene's children to add later
		for child in AsyncLoaderHelpers.recursively_get_all_children_of_type(instance, Node):
			# Get destination queue
			to = _get_destination_queue_for_instance(child, false, null)
			if to == null:
				continue

			# Get parent
			var parent = child.get_parent()
			if parent == null:
				continue

			# Get if node is sleeping
			var is_sleeping := false
			if is_sleeping_children:
				var groups = child.get_groups()
				for sleep_dis in GROUP_SLEEP_DISTANCES:
					var name = sleep_dis["name"]
					if groups.has(name):
						is_sleeping = true

			# Get data
			var data := {
				"is_child" : true,
				"instance" : child,
				"parent" : parent,
				"owner" : instance,
				"is_sleeping" : is_sleeping,
				"transform" : child.transform
			}

			# Remove node from parent and add to queue
			parent.remove_child(child)
			to.append(data)
			AsyncLoader._total_queue_count += 1

	return has_new_scenes
