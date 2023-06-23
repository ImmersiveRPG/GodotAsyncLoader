# Copyright (c) 2021-2023 Matthew Brennan Jones <matthew.brennan.jones@gmail.com>
# This file is licensed under the MIT License
# https://github.com/ImmersiveRPG/GodotAsyncLoader

extends Spatial


var _prev_player_center_tile := Vector3.INF
var _tile_load_status := []
var _sleeping_nodes := {}
var _is_first_tile := true

onready var _tile = $Tile

func _init() -> void:
	# Init a table to keep track of what tiles are loaded
	for _z in range(-Global.WORLD_TILES_WIDE, Global.WORLD_TILES_WIDE):
		var row := []
		for _x in range(-Global.WORLD_TILES_WIDE, Global.WORLD_TILES_WIDE):
			row.append(0)
		_tile_load_status.append(row)

func _ready() -> void:
	AsyncLoader._scene_sleeper._changed_tile_cb = funcref(self, "_on_changed_tile_cb")
	AsyncLoader._scene_sleeper._wake_cb = funcref(self, "_on_wake_child_cb")
	AsyncLoader._scene_sleeper._sleep_cb = funcref(self, "_on_sleep_child_cb")
	AsyncLoader._scene_sleeper._get_sleeping_children_cb = funcref(self, "_get_sleeping_children_cb")

func _on_changed_tile_cb(next_player_tile : Node) -> void:
	Global._player_tile = next_player_tile
	print("!! Player(%s) is on Tile (%s)" % [Global._player.name, next_player_tile.name])

func _on_wake_child_cb(node : Node, node_parent : Node, node_owner : Node) -> void:
	var in_tree := node.is_inside_tree()
	node_parent.add_child(node)
	print("+ waking %s, %s" % [node, in_tree])
	#yield(node, "ready")

func _on_sleep_child_cb(node : Node, node_parent : Node, node_owner : Node, is_to_be_removed : bool) -> void:
	var in_tree := node.is_inside_tree()
	if is_to_be_removed:
		node_parent.remove_child(node)

	_get_sleeping_children_cb(node_owner).append({
		"node_parent" : node_parent,
		"node" : node
	})
	print("- sleeping %s, %s" % [node, in_tree])

func _get_sleeping_children_cb(node : Node) -> Array:
	if not _sleeping_nodes.has(node.name):
		_sleeping_nodes[node.name] = []

	return _sleeping_nodes[node.name]

func _on_load_checker_timer_timeout() -> void:
	# Load around player
	if Global._player:
		var org = Global._player.transform.origin
		var center_tile := self._position_to_tile_xz(org) - Global._world_offset
		if center_tile != _prev_player_center_tile:
			_prev_player_center_tile = center_tile
			self._load_tiles_around(center_tile, 6.0) # FIXME: This should not be hard coded
			self._sleep_and_wake_nodes(center_tile)

	# Let the player move if the tiles under the player are loaded
	if not Global._is_ready_for_movement and _prev_player_center_tile != Vector3.INF:
		var is_player_tile_loaded : bool = _tile_load_status[_prev_player_center_tile.z][_prev_player_center_tile.x] == 2
		if is_player_tile_loaded:
			Global._is_ready_for_movement = true

func _load_tiles_around(center_tile : Vector3, distance : float) -> void:
	# Get tile coordinates for X distance around the center
	var to_load := [center_tile]
	for entry in to_load.duplicate():
		to_load = self._get_cells_around(to_load, entry, distance)

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

	# Wake the current tile
	AsyncLoader.wake_child_nodes(next_player_tile, 0.0)

	# Get all the children sorted by distance
	var children := []
	for tile in _tile.get_children():
		if tile != next_player_tile:
			var distance := round(next_player_tile.global_transform.origin.distance_to(tile.global_transform.origin)) / Global.TILE_WIDTH
			children.append([tile, distance])
	children.sort_custom(SortByDistance, "sort_distance")

	# Wake or sleep depending on distance
	#print("*** next: ", next_player_tile.name)
	for entry in children:
		var tile = entry[0]
		var distance = entry[1]
		#print("    tile: ", tile.name, " distance: ", distance)
		AsyncLoader.wake_or_sleep_child_nodes(tile, distance)

	AsyncLoader.change_tile(next_player_tile)
#	#print("!! Player(%s) is on Tile (%s)" % [body.name, next_player_tile.name])

class SortByDistance:
	static func sort_distance(a, b):
		return a[1] < b[1]


func _position_to_tile_xz(org : Vector3) -> Vector3:
	var half := Global.TILE_WIDTH / 2.0
	var x := round((org.x / half) / 2.0)
	var z := round((org.z / half) / 2.0)

	return Vector3(x, 0, z)

func _get_cells_around(to_load : Array, center_tile : Vector3, distance : float) -> Array:
	var data := []
	for x in range(-distance, distance + 1.0):
		for z in range(-distance, distance + 1.0):
			data.append(center_tile + Vector3(x, 0.0, z))

	for entry in data:
		if not to_load.has(entry):
			to_load.append(entry)
	return to_load
