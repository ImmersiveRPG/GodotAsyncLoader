# Copyright (c) 2021 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is license under the MIT License
# https://github.com/ImmersiveRPG/AsyncLoaderExample

extends Node

const sleep_time := 100
var _is_running := false
var _thread : Thread
var _to_add := {}
var _to_add_mutex := Mutex.new()

var to_add_terrain := []
var to_add_buildings := []
var to_add_furniture := []
var to_add_plants := []
var to_add_items := []
var to_add_npcs := []
var to_add_etc := []

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

func add_scene(on_done_cb : FuncRef, target : Node, path : String, pos : Vector3, is_pos_global : bool, cb : FuncRef, instance : Node, logs : Dictionary) -> void:
	_to_add_mutex.lock()
	if not _to_add.has(target):
		_to_add[target] = []
	_to_add[target].append({
		"on_done_cb" : on_done_cb,
		"path" : path,
		"pos" : pos,
		"is_pos_global" : is_pos_global,
		"cb" : cb,
		"instance" : instance,
		"logs" : logs,
	})
	_to_add_mutex.unlock()
	#print(_to_add)

func _can_add_terrain() -> bool:
	return not to_add_terrain.empty()

func _can_add_buildings() -> bool:
	return not to_add_buildings.empty() and not _can_add_terrain()

func _can_add_furniture() -> bool:
	return not to_add_furniture.empty() and not _can_add_buildings()

func _can_add_plants() -> bool:
	return not to_add_plants.empty() and not _can_add_furniture()

func _can_add_items() -> bool:
	return not to_add_items.empty() and not _can_add_plants()

func _can_add_npcs() -> bool:
	return not to_add_npcs.empty() and not _can_add_items()

func _can_add_etc() -> bool:
	return not to_add_etc.empty() and not _can_add_npcs()

func _run_thread(_arg : int) -> void:
	_is_running = true
	var is_reset := false

	while _is_running:
		is_reset = false
		self._check_for_new_scenes()

		while _is_running and not is_reset and _can_add_terrain():
			is_reset = _add_entry(to_add_terrain, "Terrain")

		while _is_running and not is_reset and _can_add_buildings():
			is_reset = _add_entry(to_add_buildings, "Building")

		while _is_running and not is_reset and _can_add_furniture():
			is_reset = _add_entry(to_add_furniture, "Furniture")

		while _is_running and not is_reset and _can_add_plants():
			is_reset = _add_entry(to_add_plants, "Plant")

		while _is_running and not is_reset and _can_add_items():
			is_reset = _add_entry(to_add_items, "Item")

		while _is_running and not is_reset and _can_add_npcs():
			is_reset = _add_entry(to_add_npcs, "NPC")

		while _is_running and not is_reset and _can_add_etc():
			is_reset = _add_entry(to_add_etc, "ETC")

		OS.delay_msec(2)

func _add_entry(from, message : String) -> bool:
	var entry = from.pop_front()
	if entry["is_child"]:
		_add_child(entry, message)
	else:
		_add_parent(entry, message)

	OS.delay_msec(sleep_time)
	return self._check_for_new_scenes()

func _add_child(entry, message : String) -> void:
	var parent = entry["parent"]
	var instance = entry["instance"]
	var transform = entry["transform"]
	instance.transform = transform
	self.call_deferred("_on_add_child_cb", parent, instance, message)

func _on_add_child_cb(parent : Node, instance : Node, message : String) -> void:
	var start := OS.get_ticks_msec()
	parent.add_child(instance)
	var time := OS.get_ticks_msec() - start
	print("+++ Adding %s %s %s ms" % [message, instance.name, time])

func _add_parent(entry, message : String) -> void:
	var target = entry["target"]
	var on_done_cb = entry["on_done_cb"]
	var path = entry["path"]
	var pos = entry["pos"]
	var is_pos_global = entry["is_pos_global"]
	var cb = entry["cb"]
	var instance = entry["instance"]
	var logs = entry["logs"]
	on_done_cb.call_deferred("call_func", target, path, pos, is_pos_global, cb, instance, logs)

func _get_destination_queue_for_instance(instance):
	if instance.is_in_group("terrain"):
		#print(">>> %s to %s" % [instance.name, "to_add_terrain"])
		return to_add_terrain
	elif instance.is_in_group("building"):
		#print(">>> %s to %s" % [instance.name, "to_add_buildings"])
		return to_add_buildings
	elif instance.is_in_group("furniture"):
		#print(">>> %s to %s" % [instance.name, "to_add_furniture"])
		return to_add_furniture
	elif instance.is_in_group("plant"):
		#print(">>> %s to %s" % [instance.name, "to_add_plants"])
		return to_add_plants
	elif instance.is_in_group("item"):
		#print(">>> %s to %s" % [instance.name, "to_add_items"])
		return to_add_items
	elif instance.is_in_group("npc"):
		#print(">>> %s to %s" % [instance.name, "to_add_npcs"])
		return to_add_npcs
	elif instance.is_in_group("etc"):
		#print(">>> %s to %s" % [instance.name, "to_add_npcs"])
		return to_add_etc

	return null

func _check_for_new_scenes() -> bool:
	_to_add_mutex.lock()
	var to_add := _to_add.duplicate()
	_to_add = {}
	_to_add_mutex.unlock()

	var has_new_scenes := false
	for target in to_add:
		for entry in to_add[target]:
			#OS.delay_msec(1)
			var instance = entry["instance"]

			# Add the scene
			var to = _get_destination_queue_for_instance(instance)
			if to == null:
				#print(">>> %s to %s" % [instance.name, "to_add_terrain"])
				to = to_add_terrain
			var entry_copy = entry.duplicate()
			entry_copy["target"] = target
			entry_copy["is_child"] = false
			to.append(entry_copy)
			has_new_scenes = true

			# Remove all the scene's children to add later
			for child in Global.recursively_get_all_children_of_type(instance, Node):
				to = _get_destination_queue_for_instance(child)
				if to != null:
					var parent = child.get_parent()
					if parent != null:
						to.append({ "is_child" : true, "instance" : child, "parent" : parent, "transform" : child.transform})
						parent.remove_child(child)

	return has_new_scenes
