# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Node

var _is_running := false
var _thread : Thread
var _to_sleep := []
var _to_sleep_child := []
var _to_wake := []
var _to_sleep_mutex := Mutex.new()
var _to_sleep_child_mutex := Mutex.new()
var _to_wake_mutex := Mutex.new()

var _changed_tile_cb : FuncRef = null
var _sleep_cb : FuncRef = null
var _wake_cb : FuncRef = null
var _get_sleeping_children_cb : FuncRef = null


func sleep_scene(node_owner : Node) -> void:
	_to_sleep_mutex.lock()
	_to_sleep.push_back(node_owner)
	_to_sleep_mutex.unlock()

func sleep_scene_child(node : Node, node_parent : Node, node_owner : Node) -> void:
	var entry := {
		"node" : node,
		"node_parent" : node_parent,
		"node_owner" : node_owner,
	}

	_to_sleep_child_mutex.lock()
	_to_sleep_child.push_back(entry)
	_to_sleep_child_mutex.unlock()

func wake_scene(node_owner : Node) -> void:
	_to_wake_mutex.lock()
	_to_wake.push_back(node_owner)
	_to_wake_mutex.unlock()

func _run_sleeper_thread(_arg : int) -> void:
	var config = get_node("/root/AsyncLoaderConfig")
	_is_running = true
	var is_reset := false

	while _is_running:
		_to_wake_mutex.lock()
		var node_owner = _to_wake.pop_front()
		_to_wake_mutex.unlock()
		if node_owner:
			var cb := funcref(self, "_wake_owner")
			AsyncLoader.call_throttled(cb, [node_owner, 1.0])

		_to_sleep_mutex.lock()
		node_owner = _to_sleep.pop_front()
		_to_sleep_mutex.unlock()
		if node_owner:
			var cb := funcref(self, "_sleep_owner")
			AsyncLoader.call_throttled(cb, [node_owner, 1.0, false])

		_to_sleep_child_mutex.lock()
		var entry = _to_sleep_child.pop_front()
		_to_sleep_child_mutex.unlock()
		if entry:
			var node = entry["node"]
			var node_parent = entry["node_parent"]
			node_owner = entry["node_owner"]
			#self._sleep_child(node, node_parent, node_owner, false)
			AsyncLoader.call_throttled(_sleep_cb, [node, node_parent, node_owner, false])
		OS.delay_msec(config._thread_sleep_msec)

func _sleep_owner(node_owner : Node, distance : float, is_can_sleep := true) -> void:
	#print("! sleep %s" % [node_owner])
	if node_owner == null:
		return

	var group_sleep_distances : Array
	if is_can_sleep:
		group_sleep_distances = AsyncLoader._scene_adder.GROUP_SLEEP_DISTANCES.duplicate()
	else:
		group_sleep_distances = AsyncLoader._scene_adder.GROUPS.duplicate()
	group_sleep_distances.invert()

	for info in group_sleep_distances:
		var group = info["name"]
		var dis = info["distance"]
		if distance >= dis:
			var group_nodes = AsyncLoaderHelpers.recursively_get_all_children_in_group(node_owner, group)
			group_nodes.invert()
			for node in group_nodes:
				var node_parent = node.get_parent()
				AsyncLoader.call_throttled(_sleep_cb, [node, node_parent, node_owner, true])


func sleep_child_nodes(node_owner : Node, distance : float, is_can_sleep := true) -> void:
	var cb := funcref(self, "_sleep_owner")
	AsyncLoader.call_throttled(cb, [node_owner, distance, is_can_sleep])

func _wake_owner(node_owner : Node, distance : float) -> void:
	#print("! wake %s" % [node_owner])
	if node_owner == null:
		return

	var entries = _get_sleeping_children_cb.call_func(node_owner)
	for entry in entries.duplicate():
		var node_parent = entry["node_parent"]
		var node = entry["node"]

		var name = null
		var distance_threshold := 0.0
		for info in AsyncLoader._scene_adder.GROUP_SLEEP_DISTANCES:
			if node.is_in_group(info["name"]):
				name = info["name"]
				distance_threshold = info["distance"]
				break

		#print("    threshold: ", distance_threshold)
		if name != null and distance <= distance_threshold:
			entries.erase(entry)

			AsyncLoader.call_throttled(_wake_cb, [node, node_parent, node_owner])


func wake_child_nodes(node_owner : Node, distance : float) -> void:
	var cb := funcref(self, "_wake_owner")
	AsyncLoader.call_throttled(cb, [node_owner, distance])

func wake_or_sleep_child_nodes(node_owner : Node, distance : float, is_can_sleep := true) -> void:
	# Wake children
	self.wake_child_nodes(node_owner, distance)

	# Sleep children
	self.sleep_child_nodes(node_owner, distance)

func change_tile(next_tile : Node) -> void:
	# Done changing tile
	if _changed_tile_cb:
		AsyncLoader.call_throttled(_changed_tile_cb, [next_tile])
