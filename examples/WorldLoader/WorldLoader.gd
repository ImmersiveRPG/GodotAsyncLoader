# Copyright (c) 2021-2022 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Spatial


var _prev_player_center_tile := Vector3.INF
var _tile_load_status := []
var _is_first_tile := true

onready var _tile = $Tile

func _init() -> void:
	# Init a table to keep track of what tiles are loaded
	for _z in range(-Global.WORLD_TILES_WIDE, Global.WORLD_TILES_WIDE):
		var row := []
		for _x in range(-Global.WORLD_TILES_WIDE, Global.WORLD_TILES_WIDE):
			row.append(0)
		_tile_load_status.append(row)

func _on_load_checker_timer_timeout() -> void:
	self._load_tiles_around_player()

func _load_tiles_around_player() -> void:
	# Load around player
	if Global._player:
		var org = Global._player.transform.origin
		var center_tile := self._position_to_tile_xz(org) - Global._world_offset
		if center_tile != _prev_player_center_tile:
			_prev_player_center_tile = center_tile
			self._load_tiles_around(center_tile)
			self._sleep_and_wake_nodes(center_tile)

	# Let the player move if the tiles under the player are loaded
	if not Global._is_ready_for_movement and _prev_player_center_tile != Vector3.INF:
		var is_player_tile_loaded : bool = _tile_load_status[_prev_player_center_tile.z][_prev_player_center_tile.x] == 2
		if is_player_tile_loaded:
			Global._is_ready_for_movement = true

func _load_tiles_around(center_tile : Vector3) -> void:
	# Get tile coordinates for X distance around the center
	var to_load := [center_tile]
	for n in 2:
		for entry in to_load.duplicate():
			to_load = self._get_cells_around(to_load, entry)

	# Filter out all invalid tiles
	for entry in to_load.duplicate():
		# Skip tiles that are outside the world
		if entry.x <= -Global.WORLD_TILES_WIDE \
		or entry.x >= Global.WORLD_TILES_WIDE \
		or entry.z <= -Global.WORLD_TILES_WIDE \
		or entry.z >= Global.WORLD_TILES_WIDE:
			to_load.erase(entry)
			continue

		# Skip tiles that do not exist
		var scene_path := "res://examples/Tile/Tile_%+03d_%+03d.tscn" % [entry.x, entry.z]
		if not ResourceLoader.exists(scene_path):
			to_load.erase(entry)
			continue
	#print(to_load)

	# Tell Scene loader to load tiles
	for entry in to_load:
		# Skip tiles that are already loaded or started loading
		if _tile_load_status[entry.z][entry.x] > 0:
			continue

		# Mark that this tile is starting to load
		_tile_load_status[entry.z][entry.x] = 1

		# Instance scene asynchronously and send to callback
		var data := {
			"target" : _tile,
			"pos" : Vector3(entry.x, 0.0, entry.z),
			"is_first" : _is_first_tile,
		}
		var scene_path := "res://examples/Tile/Tile_%+03d_%+03d.tscn" % [entry.x, entry.z]
		#print(scene_path)
		var cb := funcref(self, "_on_tile_loaded_cb")
		#print([cb])
		AsyncLoader.instance_with_cb(scene_path, cb, data, false)
		_is_first_tile = false

func _on_tile_loaded_cb(instance : Node, data : Dictionary) -> void:
	#print([instance])
	# Add the tile
	var target = data["target"]
	var pos = data["pos"]
	target.add_child(instance)
	var offset = (Global._world_offset * Global.TILE_WIDTH)
	instance.global_transform.origin = offset + Vector3(pos.x * Global.TILE_WIDTH, pos.y, pos.z * Global.TILE_WIDTH)

	# Mark that the tile as loaded
	_tile_load_status[pos.z][pos.x] = 2

func _sleep_and_wake_nodes(center_tile : Vector3) -> void:
	var tile_name := "Tile_%+03d_%+03d" % [center_tile.x, center_tile.z]
	var next_player_tile = _tile.get_node_or_null(tile_name)
	#print([tile_name, next_player_tile])
	if next_player_tile == null:
		return

	if Global._player_tile:
		if not Global._sleeping_nodes.has(Global._player_tile.name):
			Global._sleeping_nodes[Global._player_tile.name] = []

	if next_player_tile:
		if not Global._sleeping_nodes.has(next_player_tile.name):
			Global._sleeping_nodes[next_player_tile.name] = []

	# Wake up the on screen nodes
	var inverse_entries = Global._sleeping_nodes[next_player_tile.name]
	inverse_entries.invert()
	for entry in inverse_entries:
		var node_parent = entry["node_parent"]
		var node = entry["node"]
		#print("!!! Waking: %s" % [node.name])
		node_parent.add_child(node)
		#BlockingActionThrottler.call_on_main_thread_when_idle(node_parent, "add_child", [node], false)
	Global._sleeping_nodes[next_player_tile.name].clear()

	# Put all the off screen nodes to sleep
	var can_sleep_groups = AsyncLoader.get_can_sleep_groups()
	can_sleep_groups.invert()
	if Global._player_tile:
		for group in can_sleep_groups:
			var group_nodes = Global.recursively_get_all_children_in_group(Global._player_tile, group)
			group_nodes.invert()
			for node in group_nodes:
				#print("!!! Sleeping: %s" % [node.name])
				var node_parent = node.get_parent()
				node_parent.remove_child(node)
				#BlockingActionThrottler.call_on_main_thread_when_idle(node_parent, "remove_child", [node], false)
				Global._sleeping_nodes[Global._player_tile.name].append({
					"node_parent" : node_parent,
					"node" : node
				})

	Global._player_tile = next_player_tile
	#print("!! Player(%s) is on Tile (%s)" % [body.name, next_player_tile.name])

func _position_to_tile_xz(org : Vector3) -> Vector3:
	var half := Global.TILE_WIDTH / 2.0
	var x := round((org.x / half) / 2.0)
	var z := round((org.z / half) / 2.0)

	return Vector3(x, 0, z)

func _get_cells_around(to_load : Array, center_tile : Vector3) -> Array:
	var data := [
		center_tile, # Center
		center_tile + Vector3(-1.0, 0.0, 0.0), # Right
		center_tile + Vector3(1.0, 0.0, 0.0), # Left
		center_tile + Vector3(0.0, 0.0, 1.0), # Up
		center_tile + Vector3(0.0, 0.0, -1.0), # Down
		center_tile + Vector3(-1.0, 0.0, 1.0), # Up Right
		center_tile + Vector3(1.0, 0.0, 1.0), # Up Left
		center_tile + Vector3(-1.0, 0.0, -1.0), # Down Right
		center_tile + Vector3(1.0, 0.0, -1.0), # Down Left
	]
	for entry in data:
		if not to_load.has(entry):
			to_load.append(entry)
	return to_load
